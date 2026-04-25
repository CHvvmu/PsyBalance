-- PsyBalance MVP schema (public)
-- Dev stage: RLS/policies intentionally NOT enabled here.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text check (role in ('client', 'coach', 'administrator')) not null default 'client',
  onboarding_completed boolean not null default false,
  onboarding_goal text,
  onboarding_current_weight_kg double precision,
  onboarding_target_weight_kg double precision,
  onboarding_height_cm integer,
  onboarding_difficulties text[] not null default '{}',
  created_at timestamp with time zone default now()
);

alter table public.users
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists onboarding_goal text,
  add column if not exists onboarding_current_weight_kg double precision,
  add column if not exists onboarding_target_weight_kg double precision,
  add column if not exists onboarding_height_cm integer,
  add column if not exists onboarding_difficulties text[] not null default '{}';

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  coach_id uuid references public.users(id) on delete set null
);

create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  date date not null,
  sleep int,
  stress int,
  energy int,
  mood int
);

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  image_url text,
  meal_type text,
  notes text,
  created_at timestamp default now()
);

alter table public.food_logs
  enable row level security;

drop policy if exists "food_logs_insert_own_rows" on public.food_logs;

create policy "food_logs_insert_own_rows"
on public.food_logs
for insert
to authenticated
with check (
  user_id = auth.uid()
);

drop policy if exists "food_logs_select_own_rows" on public.food_logs;

create policy "food_logs_select_own_rows"
on public.food_logs
for select
to authenticated
using (
  user_id = auth.uid()
);

insert into storage.buckets (id, name, public)
values ('food_images', 'food_images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "food_images_insert_own_files" on storage.objects;

create policy "food_images_insert_own_files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'food_images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "food_images_select_own_files" on storage.objects;

create policy "food_images_select_own_files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'food_images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  week_start date
);

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.plans(id) on delete cascade,
  title text,
  status text,
  proof_image text
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.users(id),
  receiver_id uuid references public.users(id),
  text text,
  image_url text,
  created_at timestamp default now()
);

-- Backfill for already existing auth users.
insert into public.users (id, email, role)
select id, email, 'client'
from auth.users
on conflict (id) do nothing;

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, role)
  values (new.id, new.email, 'client')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

