-- PsyBalance MVP schema (public)
-- Coach/client flows require read access to users plus self-write for profiles.

create extension if not exists pgcrypto;
create extension if not exists pg_cron;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text check (role in ('client', 'coach', 'administrator')) not null default 'client',
  onboarding_completed boolean default false,
  onboarding_goal text,
  onboarding_current_weight_kg double precision,
  onboarding_target_weight_kg double precision,
  onboarding_height_cm integer,
  onboarding_difficulties text[] not null default '{}',
  progress_score int,
  consistency_streak int,
  engagement_level int,
  created_at timestamp with time zone default now()
);

alter table public.users
  add column if not exists onboarding_completed boolean default false,
  add column if not exists onboarding_goal text,
  add column if not exists onboarding_current_weight_kg double precision,
  add column if not exists onboarding_target_weight_kg double precision,
  add column if not exists onboarding_height_cm integer,
  add column if not exists onboarding_difficulties text[] not null default '{}';

alter table public.users
  add column if not exists avatar_url text,
  add column if not exists goal text,
  add column if not exists sleep_quality int,
  add column if not exists activity_level text,
  add column if not exists food_preferences text,
  add column if not exists updated_at timestamp default now();

alter table public.users
  add column if not exists full_name text,
  add column if not exists phone text,
  add column if not exists gender text,
  add column if not exists birth_date date,
  add column if not exists height_cm int,
  add column if not exists weight_kg int,
  add column if not exists last_activity_date timestamp with time zone,
  add column if not exists last_session_date timestamp with time zone,
  add column if not exists progress_status text,
  add column if not exists progress_score int,
  add column if not exists consistency_streak int,
  add column if not exists engagement_level int,
  add column if not exists notes text,
  add column if not exists notifications_enabled boolean default true,
  add column if not exists language text default 'ru';

alter table public.users
  alter column onboarding_completed drop not null,
  alter column last_activity_date drop default,
  alter column last_activity_date drop not null,
  alter column last_session_date drop default,
  alter column last_session_date drop not null,
  alter column progress_status drop default,
  alter column progress_status drop not null,
  alter column notes drop default,
  alter column notes drop not null;

create index if not exists idx_users_role on public.users(role);
create index if not exists idx_users_last_activity_date on public.users(last_activity_date desc);
create index if not exists idx_users_last_session_date on public.users(last_session_date desc);
create index if not exists idx_users_progress_status on public.users(progress_status);

create or replace function public._behavior_current_user_is_coach()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and coalesce(u.role, 'client') = 'coach'
  );
$$;

alter table public.users
  enable row level security;

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  coach_id uuid references public.users(id) on delete set null,
  created_at timestamp with time zone default now()
);

drop policy if exists "users_select_authenticated" on public.users;

create policy "users_select_authenticated"
on public.users
for select
to authenticated
using (
  id = auth.uid()
  or (
    coalesce(role, 'client') = 'client'
    and exists (
      select 1
      from public.clients c
      where c.user_id = public.users.id
        and c.coach_id = auth.uid()
    )
  )
  or (
    coalesce(role, 'client') = 'coach'
    and exists (
      select 1
      from public.clients c
      where c.user_id = auth.uid()
        and c.coach_id = public.users.id
    )
  )
);

drop policy if exists "users_insert_own_row" on public.users;

create policy "users_insert_own_row"
on public.users
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "users_update_own_row" on public.users;

create policy "users_update_own_row"
on public.users
for update
to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.clients c
    where c.user_id = public.users.id
      and c.coach_id = auth.uid()
  )
)
with check (
  id = auth.uid()
  or exists (
    select 1
    from public.clients c
    where c.user_id = public.users.id
      and c.coach_id = auth.uid()
  )
);

alter table public.users
  drop constraint if exists users_progress_status_check;

alter table public.users
  add constraint users_progress_status_check
  check (progress_status in ('onboarding', 'engaged', 'stable', 'inconsistent', 'struggling', 'inactive', 'beginner', 'active', 'stagnating'));

create table if not exists public.behavior_metric_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamp with time zone not null default now(),
  finished_at timestamp with time zone,
  processed_users_count int not null default 0,
  failed_calculations_count int not null default 0,
  status text not null default 'running',
  error_message text
);

alter table public.behavior_metric_runs
  enable row level security;

drop policy if exists "behavior_metric_runs_select_admins" on public.behavior_metric_runs;

create or replace function public._behavior_active_day_key(p_timestamp timestamp with time zone)
returns date
language sql
immutable
as $$
  select date_trunc('day', p_timestamp at time zone 'utc')::date;
$$;

create or replace function public._behavior_is_coach_for_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.clients c
    where c.user_id = p_user_id
      and c.coach_id = auth.uid()
  );
$$;

create or replace function public._behavior_status_from_score(
  p_score int,
  p_engagement int,
  p_streak int,
  p_days_since_last_activity int,
  p_has_signals boolean,
  p_onboarding_completed boolean
)
returns text
language plpgsql
immutable
as $$
begin
  if not p_has_signals then
    if coalesce(p_onboarding_completed, false) then
      return 'inactive';
    end if;

    return 'onboarding';
  end if;

  if p_days_since_last_activity >= 14 then
    return 'inactive';
  end if;

  if p_score >= 80 and p_engagement >= 70 and p_streak >= 5 then
    return 'stable';
  end if;

  if p_score >= 60 and p_engagement >= 45 then
    return 'engaged';
  end if;

  if p_score >= 40 then
    return 'inconsistent';
  end if;

  if p_score >= 20 then
    return 'struggling';
  end if;

  if coalesce(p_onboarding_completed, false) then
    return 'struggling';
  end if;

  return 'onboarding';
end;
$$;

create or replace function public.calculate_behavior_metrics()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run_id uuid;
  v_processed_users_count int := 0;
  v_failed_calculations_count int := 0;
  v_today date := current_date;
  v_user record;
  v_latest_task_activity timestamp with time zone;
  v_latest_checkin_activity timestamp with time zone;
  v_latest_coach_activity timestamp with time zone;
  v_latest_activity timestamp with time zone;
  v_tasks_total int;
  v_tasks_done int;
  v_tasks_in_progress int;
  v_checkin_days_total int;
  v_checkin_days_last7 int;
  v_task_completion_rate numeric;
  v_checkin_continuity numeric;
  v_activity_recency_score numeric;
  v_coach_recency_score numeric;
  v_progress_score int;
  v_engagement_level int;
  v_progress_status text;
  v_consistency_streak int;
  v_days_since_last_activity int;
  v_event_days date[];
  v_active_days_count int;
  v_recent_active_days_count int;
  v_has_signals boolean;
  v_onboarding_completed boolean;
begin
  insert into public.behavior_metric_runs (status)
  values ('running')
  returning id into v_run_id;

  for v_user in
    select u.id, coalesce(u.onboarding_completed, false) as onboarding_completed
    from public.users u
    where coalesce(u.role, 'client') = 'client'
  loop
    begin
      v_latest_task_activity := null;
      v_latest_checkin_activity := null;
      v_latest_coach_activity := null;
      v_latest_activity := null;
      v_tasks_total := 0;
      v_tasks_done := 0;
      v_tasks_in_progress := 0;
      v_checkin_days_total := 0;
      v_checkin_days_last7 := 0;
      v_task_completion_rate := 0;
      v_checkin_continuity := 0;
      v_activity_recency_score := 0;
      v_coach_recency_score := 0;
      v_progress_score := 0;
      v_engagement_level := 0;
      v_progress_status := 'onboarding';
      v_consistency_streak := 0;
      v_days_since_last_activity := 999;
      v_event_days := array[]::date[];
      v_active_days_count := 0;
      v_recent_active_days_count := 0;
      v_has_signals := false;
      v_onboarding_completed := coalesce(v_user.onboarding_completed, false);

      select
        max(coalesce(pi.updated_at, pi.created_at)),
        count(*),
        count(*) filter (where lower(coalesce(pi.status, '')) = 'done'),
        count(*) filter (where lower(coalesce(pi.status, '')) = 'in_progress')
      into v_latest_task_activity, v_tasks_total, v_tasks_done, v_tasks_in_progress
      from public.plan_items pi
      join public.plans p on p.id = pi.plan_id
      where p.user_id = v_user.id;

      select
        max(coalesce(ci.created_at, ci.date::timestamp with time zone)),
        count(distinct ci.date),
        count(distinct ci.date) filter (where ci.date >= v_today - 6)
      into v_latest_checkin_activity, v_checkin_days_total, v_checkin_days_last7
      from public.check_ins ci
      where ci.user_id = v_user.id;

      select max(m.created_at)
      into v_latest_coach_activity
      from public.messages m
      where m.sender_id = v_user.id
         or m.receiver_id = v_user.id;

      v_latest_activity := greatest(v_latest_task_activity, v_latest_checkin_activity, v_latest_coach_activity);

      if v_latest_activity is null then
        v_days_since_last_activity := 999;
      else
        v_days_since_last_activity := greatest(0, (v_today - v_latest_activity::date));
      end if;

      v_has_signals := v_latest_activity is not null;

      select coalesce(array_agg(day_key order by day_key), array[]::date[])
      into v_event_days
      from (
        select distinct _behavior_active_day_key(coalesce(pi.updated_at, pi.created_at)) as day_key
        from public.plan_items pi
        join public.plans p on p.id = pi.plan_id
        where p.user_id = v_user.id
        union
        select distinct _behavior_active_day_key(coalesce(ci.created_at, ci.date::timestamp with time zone)) as day_key
        from public.check_ins ci
        where ci.user_id = v_user.id
        union
        select distinct _behavior_active_day_key(m.created_at) as day_key
        from public.messages m
        where m.sender_id = v_user.id
           or m.receiver_id = v_user.id
      ) behavior_days;

      v_active_days_count := coalesce(array_length(v_event_days, 1), 0);

      if v_active_days_count > 0 then
        select count(*)
        into v_recent_active_days_count
        from unnest(v_event_days) as active_days(day_key)
        where active_days.day_key >= v_today - 6;
      end if;

      v_consistency_streak := 0;
      if v_event_days is not null and array_length(v_event_days, 1) is not null then
        for i in reverse array_lower(v_event_days, 1)..array_upper(v_event_days, 1) loop
          exit when v_event_days[i] is null;
          if v_event_days[i] = v_today - v_consistency_streak then
            v_consistency_streak := v_consistency_streak + 1;
          else
            exit;
          end if;
        end loop;
      end if;

      v_task_completion_rate := case
        when v_tasks_total = 0 then 0
        else greatest(0, least(1, (v_tasks_done::numeric + (v_tasks_in_progress::numeric * 0.5)) / v_tasks_total::numeric))
      end;

      v_checkin_continuity := case
        when v_checkin_days_total = 0 then 0
        else greatest(0, least(1, v_checkin_days_last7::numeric / 7))
      end;

      v_activity_recency_score := case
        when v_days_since_last_activity <= 1 then 1
        when v_days_since_last_activity <= 3 then 0.8
        when v_days_since_last_activity <= 7 then 0.5
        when v_days_since_last_activity <= 14 then 0.2
        else 0
      end;

      v_coach_recency_score := case
        when v_latest_coach_activity is null then 0
        when (v_today - v_latest_coach_activity::date) <= 1 then 1
        when (v_today - v_latest_coach_activity::date) <= 3 then 0.8
        when (v_today - v_latest_coach_activity::date) <= 7 then 0.5
        when (v_today - v_latest_coach_activity::date) <= 14 then 0.2
        else 0
      end;

      v_progress_score := round(
        greatest(0, least(100,
          (v_task_completion_rate * 50)
          + (least(v_consistency_streak, 7)::numeric / 7 * 20)
          + (v_checkin_continuity * 15)
          + (v_activity_recency_score * 15)
        ))
      )::int;

      v_engagement_level := round(
        greatest(0, least(100,
          (least(v_recent_active_days_count, 7)::numeric / 7 * 40)
          + (least(v_checkin_days_last7, 7)::numeric / 7 * 25)
          + (v_activity_recency_score * 20)
          + (v_coach_recency_score * 15)
        ))
      )::int;

      v_progress_status := _behavior_status_from_score(
        v_progress_score,
        v_engagement_level,
        v_consistency_streak,
        v_days_since_last_activity,
        v_has_signals,
        v_onboarding_completed
      );

      update public.users
      set progress_status = v_progress_status,
          progress_score = v_progress_score,
          consistency_streak = v_consistency_streak,
          last_activity_date = v_latest_activity,
          engagement_level = v_engagement_level,
          updated_at = now()
      where id = v_user.id;

      v_processed_users_count := v_processed_users_count + 1;
    exception
      when others then
        v_failed_calculations_count := v_failed_calculations_count + 1;
        raise notice 'behavior metric calculation failed for user_id=%: %', v_user.id, sqlerrm;
    end;
  end loop;

  update public.behavior_metric_runs
  set finished_at = now(),
      processed_users_count = v_processed_users_count,
      failed_calculations_count = v_failed_calculations_count,
      status = case when v_failed_calculations_count > 0 then 'completed_with_errors' else 'completed' end
  where id = v_run_id;

  raise notice 'calculate_behavior_metrics finished: processed_users_count=%, failed_calculations_count=%', v_processed_users_count, v_failed_calculations_count;
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('calculate_behavior_metrics_daily');
    perform cron.schedule(
      'calculate_behavior_metrics_daily',
      '15 2 * * *',
      'select public.calculate_behavior_metrics();'
    );
  end if;
exception
  when undefined_function then
    null;
end;
$$;

alter table public.clients
  add column if not exists created_at timestamp with time zone default now();

create index if not exists idx_clients_user_id on public.clients(user_id);
create index if not exists idx_clients_coach_id on public.clients(coach_id);
create index if not exists idx_clients_created_at on public.clients(created_at desc);

alter table public.clients
  enable row level security;

drop policy if exists "clients_select_own_or_coach" on public.clients;

create policy "clients_select_own_or_coach"
on public.clients
for select
to authenticated
using (
  user_id = auth.uid()
  or coach_id = auth.uid()
);

drop policy if exists "clients_insert_coach_only" on public.clients;

create policy "clients_insert_coach_only"
on public.clients
for insert
to authenticated
with check (
  public._behavior_current_user_is_coach()
  and coach_id = auth.uid()
);

drop policy if exists "clients_update_own_or_coach" on public.clients;

create policy "clients_update_own_or_coach"
on public.clients
for update
to authenticated
using (
  public._behavior_current_user_is_coach()
  and coach_id = auth.uid()
)
with check (
  public._behavior_current_user_is_coach()
  and coach_id = auth.uid()
);

drop policy if exists "clients_delete_coach_only" on public.clients;

create policy "clients_delete_coach_only"
on public.clients
for delete
to authenticated
using (
  public._behavior_current_user_is_coach()
  and coach_id = auth.uid()
);

create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  date date not null,
  sleep int,
  stress int,
  stress_level int,
  energy int,
  energy_level int,
  mood int,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.check_ins
  add column if not exists stress int,
  add column if not exists stress_level int,
  add column if not exists energy int,
  add column if not exists energy_level int,
  add column if not exists mood int,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now();

alter table public.check_ins
  alter column created_at set default now(),
  alter column updated_at set default now();

create or replace function public._behavior_sync_check_in_row()
returns trigger
language plpgsql
as $$
begin
  new.stress := coalesce(new.stress, new.stress_level);
  new.stress_level := new.stress;
  new.energy := coalesce(new.energy, new.energy_level);
  new.energy_level := new.energy;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists check_ins_sync_behavior_row on public.check_ins;

create trigger check_ins_sync_behavior_row
before insert or update on public.check_ins
for each row execute function public._behavior_sync_check_in_row();

update public.check_ins
set stress = coalesce(stress, stress_level),
    stress_level = coalesce(stress, stress_level),
    energy = coalesce(energy, energy_level),
    energy_level = coalesce(energy, energy_level)
where stress is null
   or stress_level is null
   or energy is null
   or energy_level is null;

create unique index if not exists idx_check_ins_user_date on public.check_ins(user_id, date);
create index if not exists idx_check_ins_date on public.check_ins(date desc);
create index if not exists idx_check_ins_user_created_at on public.check_ins(user_id, created_at desc);
create index if not exists idx_check_ins_created_at on public.check_ins(created_at desc);

alter table public.check_ins
  enable row level security;

drop policy if exists "check_ins_select_own_rows" on public.check_ins;

create policy "check_ins_select_own_rows"
on public.check_ins
for select
to authenticated
using (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "check_ins_insert_own_rows" on public.check_ins;

create policy "check_ins_insert_own_rows"
on public.check_ins
for insert
to authenticated
with check (
  user_id = auth.uid()
);

drop policy if exists "check_ins_select_coach_clients" on public.check_ins;

drop policy if exists "check_ins_update_own_rows" on public.check_ins;

create policy "check_ins_update_own_rows"
on public.check_ins
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);

create or replace function public._behavior_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public._behavior_normalize_task_activity_event()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.event_source := lower(coalesce(nullif(btrim(coalesce(new.event_source, '')), ''), 'user'));
  new.metadata := coalesce(new.metadata, '{}'::jsonb);

  if new.event_type is not null then
    new.event_type := lower(nullif(btrim(new.event_type), ''));
  end if;

  if new.event_type = 'completed' or coalesce(new.completed, false) then
    new.event_type := 'completed';
    new.completed := true;
    new.skipped := false;
    new.completed_at := coalesce(new.completed_at, now());
  elsif new.event_type = 'skipped' or coalesce(new.skipped, false) then
    new.event_type := 'skipped';
    new.completed := false;
    new.skipped := true;
    new.completed_at := null;
  elsif new.event_type = 'reopened' then
    new.completed := false;
    new.skipped := false;
    new.completed_at := null;
  else
    new.completed := coalesce(new.completed, false);
    new.skipped := coalesce(new.skipped, false);

    if not new.completed and not new.skipped then
      new.completed_at := null;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public._behavior_rebuild_task_projection_core(p_task_id uuid)
returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_latest_event_type text;
begin
  select
    case
      when ta.event_type is not null and ta.event_type <> '' then lower(ta.event_type)
      when coalesce(ta.completed, false) then 'completed'
      when coalesce(ta.skipped, false) then 'skipped'
      else null
    end
  into v_latest_event_type
  from public.task_activity ta
  where ta.task_id = p_task_id
  order by coalesce(ta.updated_at, ta.created_at) desc, ta.id desc
  limit 1;

  if v_latest_event_type is null then
    return null;
  end if;

  if v_latest_event_type = 'completed' then
    return 'done';
  elsif v_latest_event_type = 'reopened' then
    return 'in_progress';
  else
    return 'pending';
  end if;
end;
$$;

create table if not exists public.task_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  task_id uuid,
  event_type text,
  event_source text default 'user',
  metadata jsonb default '{}'::jsonb,
  completed boolean not null default false,
  skipped boolean not null default false,
  completed_at timestamp with time zone,
  updated_at timestamp with time zone default now(),
  created_at timestamp with time zone default now()
);

alter table public.task_activity
  add column if not exists task_id uuid,
  add column if not exists event_type text,
  add column if not exists event_source text default 'user',
  add column if not exists metadata jsonb default '{}'::jsonb,
  add column if not exists completed boolean not null default false,
  add column if not exists skipped boolean not null default false,
  add column if not exists completed_at timestamp with time zone,
  add column if not exists updated_at timestamp with time zone default now(),
  add column if not exists created_at timestamp with time zone default now();

alter table public.task_activity
  alter column event_source set default 'user',
  alter column metadata set default '{}'::jsonb,
  alter column updated_at set default now(),
  alter column created_at set default now();

drop trigger if exists task_activity_normalize_event on public.task_activity;

create trigger task_activity_normalize_event
before insert or update on public.task_activity
for each row execute function public._behavior_normalize_task_activity_event();

drop trigger if exists task_activity_touch_updated_at on public.task_activity;

create trigger task_activity_touch_updated_at
before insert or update on public.task_activity
for each row execute function public._behavior_touch_updated_at();

create index if not exists idx_task_activity_user_id on public.task_activity(user_id);
create index if not exists idx_task_activity_created_at on public.task_activity(created_at desc);
create index if not exists idx_task_activity_completed_at on public.task_activity(completed_at desc);
create index if not exists idx_task_activity_task_id_updated_at on public.task_activity(task_id, updated_at desc);

alter table public.task_activity
  enable row level security;

drop policy if exists "task_activity_select_own_rows" on public.task_activity;

create policy "task_activity_select_own_rows"
on public.task_activity
for select
to authenticated
using (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "task_activity_insert_own_rows" on public.task_activity;

create policy "task_activity_insert_own_rows"
on public.task_activity
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.plan_items pi
    join public.plans p on p.id = pi.plan_id
    where pi.id = task_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "task_activity_update_own_rows" on public.task_activity;

create policy "task_activity_update_own_rows"
on public.task_activity
for update
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.plan_items pi
    join public.plans p on p.id = pi.plan_id
    where pi.id = task_id
      and p.user_id = auth.uid()
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.plan_items pi
    join public.plans p on p.id = pi.plan_id
    where pi.id = task_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "task_activity_delete_own_rows" on public.task_activity;

create policy "task_activity_delete_own_rows"
on public.task_activity
for delete
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.plan_items pi
    join public.plans p on p.id = pi.plan_id
    where pi.id = task_id
      and p.user_id = auth.uid()
  )
);

create or replace function public.rebuild_task_projection(task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
  v_new_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select p.user_id
  into v_owner_id
  from public.plan_items pi
  join public.plans p on p.id = pi.plan_id
  where pi.id = task_id
  limit 1;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Access denied for task projection rebuild' using errcode = '42501';
  end if;

  v_new_status := public._behavior_rebuild_task_projection_core(task_id);

  if v_new_status is null then
    return;
  end if;

  update public.plan_items
  set status = v_new_status,
      updated_at = now()
  where id = task_id;
end;
$$;

create or replace function public.record_task_event(
  task_id uuid,
  event_type text,
  event_source text default 'user',
  metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
  v_event_type text := lower(nullif(btrim(coalesce(event_type, '')), ''));
  v_event_source text := lower(coalesce(nullif(btrim(coalesce(event_source, '')), ''), 'user'));
  v_metadata jsonb := coalesce(metadata, '{}'::jsonb);
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if v_event_type is null or v_event_type not in ('completed', 'skipped', 'reopened') then
    raise exception 'Unsupported task event type: %', event_type using errcode = '23514';
  end if;

  select p.user_id
  into v_owner_id
  from public.plan_items pi
  join public.plans p on p.id = pi.plan_id
  where pi.id = task_id
  limit 1;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Access denied for task event' using errcode = '42501';
  end if;

  insert into public.task_activity (
    user_id,
    task_id,
    event_type,
    event_source,
    metadata
  )
  values (
    auth.uid(),
    task_id,
    v_event_type,
    v_event_source,
    v_metadata
  );

  perform public.rebuild_task_projection(task_id);
end;
$$;

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

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "avatars_insert_own_files" on storage.objects;

create policy "avatars_insert_own_files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_update_own_files" on storage.objects;

create policy "avatars_update_own_files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_select_own_files" on storage.objects;

create policy "avatars_select_own_files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  week_start date,
  created_at timestamp default now()
);

alter table public.plans
  add column if not exists created_at timestamp default now();

create index if not exists idx_plans_user_id on public.plans(user_id);
create index if not exists idx_plans_week_start on public.plans(week_start desc);
create index if not exists idx_plans_created_at on public.plans(created_at desc);

alter table public.plans
  enable row level security;

drop policy if exists "plans_select_own_or_coach" on public.plans;

create policy "plans_select_own_or_coach"
on public.plans
for select
to authenticated
using (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "plans_insert_coach_only" on public.plans;

create policy "plans_insert_coach_only"
on public.plans
for insert
to authenticated
with check (
  public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "plans_update_own_or_coach" on public.plans;

create policy "plans_update_own_or_coach"
on public.plans
for update
to authenticated
using (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
)
with check (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "plans_delete_coach_only" on public.plans;

create policy "plans_delete_coach_only"
on public.plans
for delete
to authenticated
using (
  public._behavior_is_coach_for_user(user_id)
);

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.plans(id) on delete cascade,
  title text,
  description text,
  status text default 'pending',
  created_at timestamp default now(),
  updated_at timestamp default now(),
  proof_image text
);

alter table public.plan_items
  add column if not exists description text,
  add column if not exists created_at timestamp default now(),
  add column if not exists updated_at timestamp default now();

alter table public.plan_items
  alter column status set default 'pending';

alter table public.plan_items
  drop constraint if exists plan_items_status_check;

alter table public.plan_items
  add constraint plan_items_status_check
  check (status in ('pending', 'in_progress', 'done'));

update public.plan_items
set status = 'pending'
where status is null or trim(status) = '';

alter table public.plan_items
  alter column status set not null;

create index if not exists idx_plan_items_plan_id on public.plan_items(plan_id);
create index if not exists idx_plan_items_status on public.plan_items(status);
create index if not exists idx_plan_items_created_at on public.plan_items(created_at desc);
create index if not exists idx_plan_items_updated_at on public.plan_items(updated_at desc);

alter table public.plan_items
  enable row level security;

drop policy if exists "plan_items_select_own_or_coach" on public.plan_items;

create policy "plan_items_select_own_or_coach"
on public.plan_items
for select
to authenticated
using (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and (
        p.user_id = auth.uid()
        or public._behavior_is_coach_for_user(p.user_id)
      )
  )
);

drop policy if exists "plan_items_insert_own_or_coach" on public.plan_items;

create policy "plan_items_insert_own_or_coach"
on public.plan_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and (
        p.user_id = auth.uid()
        or public._behavior_is_coach_for_user(p.user_id)
      )
  )
);

drop policy if exists "plan_items_update_own_or_coach" on public.plan_items;

create policy "plan_items_update_own_or_coach"
on public.plan_items
for update
to authenticated
using (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and (
        p.user_id = auth.uid()
        or public._behavior_is_coach_for_user(p.user_id)
      )
  )
)
with check (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and (
        p.user_id = auth.uid()
        or public._behavior_is_coach_for_user(p.user_id)
      )
  )
);

drop policy if exists "plan_items_delete_own_or_coach" on public.plan_items;

create policy "plan_items_delete_own_or_coach"
on public.plan_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and (
        p.user_id = auth.uid()
        or public._behavior_is_coach_for_user(p.user_id)
      )
  )
);

alter table public.task_activity
  drop constraint if exists task_activity_task_id_fkey;

alter table public.task_activity
  add constraint task_activity_task_id_fkey
  foreign key (task_id) references public.plan_items(id) on delete cascade not valid;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.users(id) on delete cascade,
  coach_id uuid references public.users(id) on delete cascade,
  last_message_at timestamp with time zone,
  last_message_preview text,
  last_message_sender_id uuid references public.users(id) on delete set null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.conversations
  add column if not exists last_message_at timestamp with time zone,
  add column if not exists last_message_preview text,
  add column if not exists last_message_sender_id uuid references public.users(id) on delete set null,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists updated_at timestamp with time zone default now();

alter table public.conversations
  drop constraint if exists conversations_client_and_coach_different;

alter table public.conversations
  add constraint conversations_client_and_coach_different
  check (client_id is null or coach_id is null or client_id <> coach_id);

create unique index if not exists idx_conversations_client_coach on public.conversations(client_id, coach_id);
create index if not exists idx_conversations_client_id on public.conversations(client_id);
create index if not exists idx_conversations_coach_id on public.conversations(coach_id);
create index if not exists idx_conversations_last_message_at on public.conversations(last_message_at desc);

alter table public.conversations
  enable row level security;

drop policy if exists "conversations_select_participants" on public.conversations;

create policy "conversations_select_participants"
on public.conversations
for select
to authenticated
using (
  client_id = auth.uid()
  or coach_id = auth.uid()
);

drop policy if exists "conversations_insert_participants" on public.conversations;

create policy "conversations_insert_participants"
on public.conversations
for insert
to authenticated
with check (
  (
    auth.uid() = client_id
    or auth.uid() = coach_id
  )
  and exists (
    select 1
    from public.clients c
    where c.user_id = client_id
      and c.coach_id = coach_id
  )
);

create or replace function public._behavior_normalize_message_record()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.message_type := lower(coalesce(nullif(btrim(coalesce(new.message_type, '')), ''), 'text'));
  new.sender_role := lower(coalesce(nullif(btrim(coalesce(new.sender_role, '')), ''), 'client'));
  new.metadata := coalesce(new.metadata, '{}'::jsonb);

  if new.content is null or btrim(new.content) = '' then
    new.content := nullif(btrim(coalesce(new.text, '')), '');
  else
    new.content := btrim(new.content);
  end if;

  if new.content is null then
    raise exception 'Message content is required' using errcode = '23502';
  end if;

  new.text := new.content;

  return new;
end;
$$;

create or replace function public._behavior_sync_conversation_from_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_preview text;
begin
  v_preview := left(coalesce(nullif(btrim(new.content), ''), 'Сообщение'), 160);

  update public.conversations
  set last_message_at = coalesce(new.created_at, now()),
      last_message_preview = v_preview,
      last_message_sender_id = new.sender_id,
      updated_at = now()
  where id = new.conversation_id;

  return new;
end;
$$;

create or replace function public._behavior_is_conversation_participant(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.conversations c
    where c.id = p_conversation_id
      and (
        c.client_id = auth.uid()
        or c.coach_id = auth.uid()
      )
  );
$$;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade,
  sender_id uuid references public.users(id) on delete cascade,
  receiver_id uuid references public.users(id) on delete cascade,
  sender_role text default 'client',
  message_type text default 'text',
  content text,
  metadata jsonb default '{}'::jsonb,
  read_at timestamp with time zone,
  edited_at timestamp with time zone,
  deleted_at timestamp with time zone,
  text text,
  image_url text,
  created_at timestamp with time zone default now()
);

alter table public.messages
  add column if not exists conversation_id uuid,
  add column if not exists sender_role text default 'client',
  add column if not exists message_type text default 'text',
  add column if not exists content text,
  add column if not exists metadata jsonb default '{}'::jsonb,
  add column if not exists read_at timestamp with time zone,
  add column if not exists edited_at timestamp with time zone,
  add column if not exists deleted_at timestamp with time zone,
  add column if not exists text text,
  add column if not exists image_url text,
  add column if not exists created_at timestamp with time zone default now();

alter table public.messages
  drop constraint if exists messages_conversation_id_fkey;

alter table public.messages
  add constraint messages_conversation_id_fkey
  foreign key (conversation_id) references public.conversations(id) on delete cascade;

alter table public.messages
  drop constraint if exists messages_message_type_check;

alter table public.messages
  add constraint messages_message_type_check
  check (message_type in ('text', 'system', 'intervention', 'reflection_prompt', 'coach_note', 'checkin_followup'));

alter table public.messages
  drop constraint if exists messages_sender_role_check;

alter table public.messages
  add constraint messages_sender_role_check
  check (sender_role in ('client', 'coach', 'system', 'ai'));

update public.messages
set content = coalesce(content, nullif(btrim(text), ''))
where content is null and coalesce(text, '') <> '';

update public.messages
set text = coalesce(text, content)
where coalesce(text, '') = '' and content is not null;

update public.messages
set message_type = coalesce(nullif(btrim(message_type), ''), 'text');

update public.messages
set sender_role = coalesce(nullif(btrim(sender_role), ''), 'client');

create index if not exists idx_messages_conversation_id on public.messages(conversation_id);
create index if not exists idx_messages_conversation_created_at on public.messages(conversation_id, created_at desc);
create index if not exists idx_messages_sender_id on public.messages(sender_id);
create index if not exists idx_messages_receiver_id on public.messages(receiver_id);
create index if not exists idx_messages_created_at on public.messages(created_at desc);
create index if not exists idx_messages_unread_receiver on public.messages(receiver_id, conversation_id, created_at desc) where read_at is null and deleted_at is null;

alter table public.messages
  enable row level security;

drop policy if exists "messages_select_participants" on public.messages;

create policy "messages_select_participants"
on public.messages
for select
to authenticated
using (
  (
    conversation_id is null
    and (
      sender_id = auth.uid()
      or receiver_id = auth.uid()
    )
  )
  or public._behavior_is_conversation_participant(conversation_id)
);

drop policy if exists "messages_insert_participants" on public.messages;

create policy "messages_insert_participants"
on public.messages
for insert
to authenticated
with check (
  conversation_id is not null
  and sender_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = conversation_id
      and (
        (auth.uid() = c.client_id and receiver_id = c.coach_id)
        or (auth.uid() = c.coach_id and receiver_id = c.client_id)
      )
  )
);

drop policy if exists "messages_update_participants" on public.messages;

create policy "messages_update_participants"
on public.messages
for update
to authenticated
using (
  conversation_id is not null
  and (
    sender_id = auth.uid()
    or receiver_id = auth.uid()
  )
  and public._behavior_is_conversation_participant(conversation_id)
)
with check (
  conversation_id is not null
  and (
    sender_id = auth.uid()
    or receiver_id = auth.uid()
  )
  and public._behavior_is_conversation_participant(conversation_id)
);

drop policy if exists "messages_delete_participants" on public.messages;

create policy "messages_delete_participants"
on public.messages
for delete
to authenticated
using (
  conversation_id is not null
  and sender_id = auth.uid()
  and public._behavior_is_conversation_participant(conversation_id)
);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.conversations;
    exception when duplicate_object then
      null;
    end;

    begin
      alter publication supabase_realtime add table public.messages;
    exception when duplicate_object then
      null;
    end;
  end if;
end;
$$;

drop trigger if exists messages_normalize_record on public.messages;

create trigger messages_normalize_record
before insert or update on public.messages
for each row execute function public._behavior_normalize_message_record();

drop trigger if exists messages_sync_conversation on public.messages;

create trigger messages_sync_conversation
after insert on public.messages
for each row execute function public._behavior_sync_conversation_from_message();

create or replace function public._behavior_guard_message_update()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.uid() = old.sender_id then
    if new.id is distinct from old.id
       or new.conversation_id is distinct from old.conversation_id
       or new.sender_id is distinct from old.sender_id
       or new.receiver_id is distinct from old.receiver_id
       or new.sender_role is distinct from old.sender_role
       or new.message_type is distinct from old.message_type
       or new.created_at is distinct from old.created_at
       or new.read_at is distinct from old.read_at then
      raise exception 'Sender may only edit message content' using errcode = '42501';
    end if;

    return new;
  end if;

  if auth.uid() = old.receiver_id then
    if new.id is distinct from old.id
       or new.conversation_id is distinct from old.conversation_id
       or new.sender_id is distinct from old.sender_id
       or new.receiver_id is distinct from old.receiver_id
       or new.sender_role is distinct from old.sender_role
       or new.message_type is distinct from old.message_type
       or coalesce(new.content, '') is distinct from coalesce(old.content, '')
       or coalesce(new.text, '') is distinct from coalesce(old.text, '')
       or coalesce(new.metadata, '{}'::jsonb) is distinct from coalesce(old.metadata, '{}'::jsonb)
       or new.edited_at is distinct from old.edited_at
       or new.deleted_at is distinct from old.deleted_at
       or new.created_at is distinct from old.created_at then
      raise exception 'Receiver may only update read state' using errcode = '42501';
    end if;

    return new;
  end if;

  raise exception 'Access denied for message update' using errcode = '42501';
end;
$$;

drop trigger if exists messages_guard_update on public.messages;

create trigger messages_guard_update
after update on public.messages
for each row execute function public._behavior_guard_message_update();

create or replace function public.get_or_create_direct_conversation(p_peer_user_id uuid)
returns public.conversations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_current_role text;
  v_client_id uuid;
  v_coach_id uuid;
  v_conversation public.conversations%rowtype;
begin
  if v_current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_peer_user_id is null then
    raise exception 'Peer user is required' using errcode = '22004';
  end if;

  select lower(coalesce(role, 'client'))
  into v_current_role
  from public.users
  where id = v_current_user_id;

  if v_current_role not in ('client', 'coach') then
    raise exception 'Unsupported role for direct conversation' using errcode = '42501';
  end if;

  if v_current_role = 'coach' then
    v_client_id := p_peer_user_id;
    v_coach_id := v_current_user_id;
  else
    v_client_id := v_current_user_id;
    v_coach_id := p_peer_user_id;
  end if;

  if v_client_id = v_coach_id then
    raise exception 'Conversation participants must differ' using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.clients c
    where c.user_id = v_client_id
      and c.coach_id = v_coach_id
  ) then
    raise exception 'Conversation participants are not linked' using errcode = '42501';
  end if;

  select *
  into v_conversation
  from public.conversations
  where client_id = v_client_id
    and coach_id = v_coach_id
  limit 1;

  if v_conversation.id is null then
    insert into public.conversations (client_id, coach_id)
    values (v_client_id, v_coach_id)
    returning * into v_conversation;
  end if;

  return v_conversation;
end;
$$;

create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_content text,
  p_message_type text default 'text',
  p_metadata jsonb default '{}'::jsonb
)
returns public.messages
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_conversation public.conversations%rowtype;
  v_sender_role text;
  v_receiver_id uuid;
  v_message public.messages%rowtype;
  v_message_type text := lower(nullif(btrim(coalesce(p_message_type, '')), ''));
begin
  if v_current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_conversation_id is null then
    raise exception 'Conversation is required' using errcode = '22004';
  end if;

  if v_message_type is null then
    v_message_type := 'text';
  end if;

  if v_message_type not in ('text', 'system', 'intervention', 'reflection_prompt', 'coach_note', 'checkin_followup') then
    raise exception 'Unsupported message type: %', p_message_type using errcode = '23514';
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  limit 1;

  if v_conversation.id is null then
    raise exception 'Conversation not found' using errcode = 'P0002';
  end if;

  if v_current_user_id <> v_conversation.client_id
     and v_current_user_id <> v_conversation.coach_id then
    raise exception 'Access denied for conversation' using errcode = '42501';
  end if;

  select lower(coalesce(role, 'client'))
  into v_sender_role
  from public.users
  where id = v_current_user_id;

  if v_sender_role not in ('client', 'coach') then
    v_sender_role := 'client';
  end if;

  if nullif(btrim(coalesce(p_content, '')), '') is null then
    raise exception 'Message content is required' using errcode = '23502';
  end if;

  v_receiver_id := case
    when v_current_user_id = v_conversation.client_id then v_conversation.coach_id
    else v_conversation.client_id
  end;

  insert into public.messages (
    conversation_id,
    sender_id,
    receiver_id,
    sender_role,
    message_type,
    content,
    text,
    metadata
  )
  values (
    p_conversation_id,
    v_current_user_id,
    v_receiver_id,
    v_sender_role,
    v_message_type,
    btrim(p_content),
    btrim(p_content),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_message;

  return v_message;
end;
$$;

create or replace function public.mark_conversation_messages_read(p_conversation_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_rows int := 0;
begin
  if v_current_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_conversation_id is null then
    return 0;
  end if;

  if not public._behavior_is_conversation_participant(p_conversation_id) then
    raise exception 'Access denied for conversation' using errcode = '42501';
  end if;

  update public.messages
  set read_at = coalesce(read_at, now())
  where conversation_id = p_conversation_id
    and receiver_id = v_current_user_id
    and read_at is null
    and deleted_at is null;

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

create or replace function public.get_conversation_unread_count(p_conversation_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::bigint
  from public.messages m
  join public.conversations c on c.id = m.conversation_id
  where m.conversation_id = p_conversation_id
    and m.read_at is null
    and m.deleted_at is null
    and (
      c.client_id = auth.uid()
      or c.coach_id = auth.uid()
    );
$$;

create or replace function public.list_my_conversation_unread_counts()
returns table (
  conversation_id uuid,
  unread_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    m.conversation_id,
    count(*)::bigint as unread_count
  from public.messages m
  join public.conversations c on c.id = m.conversation_id
  where m.read_at is null
    and m.deleted_at is null
    and (
      c.client_id = auth.uid()
      or c.coach_id = auth.uid()
    )
  group by m.conversation_id;
$$;

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
