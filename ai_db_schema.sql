-- =========================
create table if not exists public.food_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_url text not null,
  meal_type text check (meal_type in ('breakfast','lunch','dinner','snack')),
  created_at timestamp default now()
);

create index if not exists idx_foodlogs_user_id on public.food_logs(user_id);

-- =========================
-- PLANS
-- =========================
create table if not exists public.plans (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  week_start date not null,
  created_at timestamp default now()
);

create index if not exists idx_plans_user_id on public.plans(user_id);

-- =========================
-- PLAN ITEMS
-- =========================
create table if not exists public.plan_items (
  id uuid primary key default uuid_generate_v4(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  title text not null,
  status text default 'not_done' check (status in ('done','not_done','partial')),
  proof_image text,
  created_at timestamp default now()
);

create index if not exists idx_planitems_plan_id on public.plan_items(plan_id);

-- =========================
-- MESSAGES
-- =========================
create table if not exists public.messages (
  id uuid primary key default uuid_generate_v4(),
  sender_id uuid not null references public.users(id) on delete cascade,
  receiver_id uuid not null references public.users(id) on delete cascade,
  text text,
  image_url text,
  created_at timestamp default now()
);

create index if not exists idx_messages_sender on public.messages(sender_id);
create index if not exists idx_messages_receiver on public.messages(receiver_id);

-- =========================
-- ROW LEVEL SECURITY (DEV MODE - OPEN ACCESS)
-- =========================

alter table public.users enable row level security;
alter table public.clients enable row level security;
alter table public.check_ins enable row level security;
alter table public.food_logs enable row level security;
alter table public.plans enable row level security;
alter table public.plan_items enable row level security;
alter table public.messages enable row level security;

-- DEV OPEN POLICIES
create policy if not exists "dev_full_access_users" on public.users for all using (true) with check (true);
create policy if not exists "dev_full_access_clients" on public.clients for all using (true) with check (true);
create policy if not exists "dev_full_access_checkins" on public.check_ins for all using (true) with check (true);
create policy if not exists "dev_full_access_foodlogs" on public.food_logs for all using (true) with check (true);
create policy if not exists "dev_full_access_plans" on public.plans for all using (true) with check (true);
create policy if not exists "dev_full_access_planitems" on public.plan_items for all using (true) with check (true);
create policy if not exists "dev_full_access_messages" on public.messages for all using (true) with check (true);

-- =========================
-- NOTES
-- =========================
-- DEV MODE ONLY
-- Replace policies before production

-- =========================
-- DONE
-- =========================