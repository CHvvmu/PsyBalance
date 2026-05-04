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

alter table public.task_activity
  add column if not exists request_key text,
  add column if not exists source_event_key text,
  add column if not exists task_snapshot jsonb default '{}'::jsonb,
  add column if not exists archived_at timestamp with time zone;

update public.task_activity
set task_snapshot = coalesce(task_snapshot, '{}'::jsonb)
where task_snapshot is null;

create unique index if not exists idx_task_activity_request_key on public.task_activity(task_id, request_key) where request_key is not null;
create unique index if not exists idx_task_activity_source_event_key on public.task_activity(source_event_key) where source_event_key is not null;

create or replace function public._behavior_block_task_activity_mutation()
returns trigger
language plpgsql
as $$
begin
  if public._behavior_is_maintenance_actor() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  raise exception 'task_activity is append-only' using errcode = '42501';
end;
$$;

drop trigger if exists task_activity_block_update on public.task_activity;
create trigger task_activity_block_update
before update on public.task_activity
for each row execute function public._behavior_block_task_activity_mutation();

drop trigger if exists task_activity_block_delete on public.task_activity;
create trigger task_activity_block_delete
before delete on public.task_activity
for each row execute function public._behavior_block_task_activity_mutation();

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
  or public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "task_activity_update_own_rows" on public.task_activity;

create policy "task_activity_update_own_rows"
on public.task_activity
for update
to authenticated
using (false)
with check (false);

drop policy if exists "task_activity_delete_own_rows" on public.task_activity;

create policy "task_activity_delete_own_rows"
on public.task_activity
for delete
to authenticated
using (false);

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

  if v_owner_id <> auth.uid() and not public._behavior_is_coach_for_user(v_owner_id) then
    raise exception 'Access denied for task projection rebuild' using errcode = '42501';
  end if;

  perform set_config('app.behavior_projection', '1', true);

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
  v_request_key text := public._behavior_task_request_key(task_id, v_event_type, coalesce(v_metadata ->> 'request_key', v_metadata ->> 'operation_id'));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if v_event_type is null or v_event_type not in ('completed', 'skipped', 'reopened', 'created') then
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

  if exists (
    select 1
    from public.task_activity ta
    where ta.task_id = task_id
      and lower(coalesce(nullif(btrim(coalesce(ta.request_key, '')), ''), '')) = lower(v_request_key)
  ) then
    perform public.rebuild_task_projection(task_id);
    return;
  end if;

  insert into public.task_activity (
    user_id,
    task_id,
    event_type,
    event_source,
    metadata,
    request_key,
    source_event_key,
    task_snapshot
  )
  values (
    auth.uid(),
    task_id,
    v_event_type,
    v_event_source,
    jsonb_strip_nulls(v_metadata || jsonb_build_object('request_key', v_request_key)),
    v_request_key,
    format('task_activity:%s:%s', task_id, v_request_key),
    jsonb_strip_nulls(jsonb_build_object(
      'task_id', task_id,
      'event_type', v_event_type,
      'event_source', v_event_source
    ))
  );

  perform public.rebuild_task_projection(task_id);
end;
$$;

create or replace function public._behavior_append_task_event(
  p_task_id uuid,
  p_actor_user_id uuid,
  p_event_type text,
  p_event_source text,
  p_metadata jsonb default '{}'::jsonb,
  p_request_key text default null,
  p_completed boolean default false,
  p_skipped boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_event_type text := public._behavior_task_event_type(p_event_type, p_completed, p_skipped);
  v_request_key text := public._behavior_task_request_key(p_task_id, coalesce(v_event_type, p_event_type), p_request_key);
  v_existing_id uuid;
  v_metadata jsonb := jsonb_strip_nulls(coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('request_key', v_request_key));
begin
  if p_task_id is null or p_actor_user_id is null or v_event_type is null then
    return null;
  end if;

  select ta.id
  into v_existing_id
  from public.task_activity ta
  where ta.task_id = p_task_id
    and lower(coalesce(nullif(btrim(coalesce(ta.request_key, '')), ''), '')) = lower(v_request_key)
  limit 1;

  if v_existing_id is not null then
    perform public.rebuild_task_projection(p_task_id);
    return v_existing_id;
  end if;

  insert into public.task_activity (
    user_id,
    task_id,
    event_type,
    event_source,
    metadata,
    completed,
    skipped,
    completed_at,
    request_key,
    source_event_key,
    task_snapshot
  )
  values (
    p_actor_user_id,
    p_task_id,
    v_event_type,
    coalesce(nullif(btrim(coalesce(p_event_source, '')), ''), 'user'),
    v_metadata,
    coalesce(p_completed, false),
    coalesce(p_skipped, false),
    case when v_event_type = 'completed' or v_event_type = 'task_completed' then now() else null end,
    v_request_key,
    format('task_activity:%s:%s', p_task_id, v_request_key),
    jsonb_strip_nulls(jsonb_build_object(
      'task_id', p_task_id,
      'event_type', v_event_type,
      'event_source', coalesce(nullif(btrim(coalesce(p_event_source, '')), ''), 'user')
    ))
  )
  returning id into v_existing_id;

  perform public.rebuild_task_projection(p_task_id);
  return v_existing_id;
end;
$$;

create or replace function public.create_plan_item(
  p_client_id uuid,
  p_title text,
  p_description text default null,
  p_scheduled_at timestamp with time zone default null,
  p_week_start date default null,
  p_category text default null,
  p_request_key text default null
)
returns public.plan_items
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_title text := public._behavior_clean_text(p_title);
  v_description text := public._behavior_clean_text(p_description);
  v_category text := public._behavior_clean_text(p_category);
  v_request_key text := lower(public._behavior_clean_text(p_request_key));
  v_plan_id uuid;
  v_existing_row public.plan_items%rowtype;
  v_row public.plan_items%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if v_title is null then
    raise exception 'Task title is required' using errcode = '23502';
  end if;

  if p_client_id is null then
    raise exception 'Client is required' using errcode = '23502';
  end if;

  if auth.uid() <> p_client_id and not public._behavior_is_coach_for_user(p_client_id) then
    raise exception 'Access denied for plan item creation' using errcode = '42501';
  end if;

  if public._behavior_clean_text(p_request_key) is null then
    raise exception 'Request key is required' using errcode = '23502';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(format('create_plan_item:%s', p_client_id::text)),
    hashtext(v_request_key)
  );

  select pi.*
  into v_existing_row
  from public.task_activity ta
  join public.plan_items pi on pi.id = ta.task_id
  join public.plans p on p.id = pi.plan_id
  where lower(coalesce(nullif(btrim(coalesce(ta.request_key, '')), ''), '')) = lower(v_request_key)
    and p.user_id = p_client_id
  order by ta.created_at desc, ta.id desc
  limit 1;

  if v_existing_row.id is not null then
    return v_existing_row;
  end if;

  select id
  into v_plan_id
  from public.get_or_create_active_plan(
    p_client_id,
    coalesce(
      p_week_start,
      current_date - (extract(isodow from current_date)::int - 1)
    )
  );

  insert into public.plan_items (
    plan_id,
    title,
    description,
    status,
    created_at,
    updated_at,
    scheduled_at,
    task_category
  )
  values (
    v_plan_id,
    v_title,
    v_description,
    'pending',
    coalesce(p_scheduled_at, now()),
    now(),
    p_scheduled_at,
    v_category
  )
  returning * into v_row;

  perform public._behavior_append_task_event(
    p_task_id := v_row.id,
    p_actor_user_id := p_client_id,
    p_event_type := 'created',
    p_event_source := 'coach',
    p_metadata := jsonb_strip_nulls(jsonb_build_object(
      'request_key', v_request_key,
      'plan_id', v_plan_id,
      'task_title', v_title,
      'task_description', v_description,
      'scheduled_at', p_scheduled_at,
      'category', v_category,
      'primary_user_id', p_client_id
    )),
    p_request_key := v_request_key
  );

  update public.plan_items
  set status = 'pending',
      updated_at = now()
  where id = v_row.id;

  return v_row;
end;
$$;

create or replace function public.update_plan_item(
  p_task_id uuid,
  p_title text default null,
  p_description text default null,
  p_scheduled_at timestamp with time zone default null,
  p_category text default null,
  p_request_key text default null
)
returns public.plan_items
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
  v_title text := public._behavior_clean_text(p_title);
  v_description text := public._behavior_clean_text(p_description);
  v_category text := public._behavior_clean_text(p_category);
  v_row public.plan_items%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select public._behavior_task_owner_id(p_task_id)
  into v_owner_id;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if auth.uid() <> v_owner_id and not public._behavior_is_coach_for_user(v_owner_id) then
    raise exception 'Access denied for task update' using errcode = '42501';
  end if;

  update public.plan_items
  set title = coalesce(v_title, title),
      description = coalesce(v_description, description),
      scheduled_at = coalesce(p_scheduled_at, scheduled_at),
      task_category = coalesce(v_category, task_category),
      updated_at = now()
  where id = p_task_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.complete_task(
  p_task_id uuid,
  p_request_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select public._behavior_task_owner_id(p_task_id)
  into v_owner_id;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Access denied for completing task' using errcode = '42501';
  end if;

  perform public._behavior_append_task_event(
    p_task_id := p_task_id,
    p_actor_user_id := v_owner_id,
    p_event_type := 'completed',
    p_event_source := 'user',
    p_metadata := p_metadata,
    p_request_key := p_request_key,
    p_completed := true
  );
end;
$$;

create or replace function public.skip_task(
  p_task_id uuid,
  p_request_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select public._behavior_task_owner_id(p_task_id)
  into v_owner_id;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if v_owner_id <> auth.uid() then
    raise exception 'Access denied for skipping task' using errcode = '42501';
  end if;

  perform public._behavior_append_task_event(
    p_task_id := p_task_id,
    p_actor_user_id := v_owner_id,
    p_event_type := 'skipped',
    p_event_source := 'user',
    p_metadata := p_metadata,
    p_request_key := p_request_key,
    p_skipped := true
  );
end;
$$;

create or replace function public.reopen_task(
  p_task_id uuid,
  p_request_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select public._behavior_task_owner_id(p_task_id)
  into v_owner_id;

  if v_owner_id is null then
    raise exception 'Task not found' using errcode = 'P0002';
  end if;

  if auth.uid() <> v_owner_id and not public._behavior_is_coach_for_user(v_owner_id) then
    raise exception 'Access denied for reopening task' using errcode = '42501';
  end if;

  perform public._behavior_append_task_event(
    p_task_id := p_task_id,
    p_actor_user_id := v_owner_id,
    p_event_type := 'reopened',
    p_event_source := case when auth.uid() = v_owner_id then 'user' else 'coach' end,
    p_metadata := jsonb_strip_nulls(p_metadata || jsonb_build_object('request_key', p_request_key, 'reopener_id', auth.uid())),
    p_request_key := p_request_key
  );
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

drop policy if exists "plans_insert_own_or_coach" on public.plans;

create policy "plans_insert_own_or_coach"
on public.plans
for insert
to authenticated
with check (
  user_id = auth.uid()
  or public._behavior_is_coach_for_user(user_id)
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

create or replace function public.get_or_create_active_plan(
  p_user_id uuid,
  p_week_start date default null
)
returns public.plans
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_week_start date := coalesce(p_week_start, current_date - (extract(isodow from current_date)::int - 1));
  v_plan public.plans%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_user_id is null then
    raise exception 'User is required' using errcode = '23502';
  end if;

  if auth.uid() <> p_user_id and not public._behavior_is_coach_for_user(p_user_id) then
    raise exception 'Access denied for active plan' using errcode = '42501';
  end if;

  select *
  into v_plan
  from public.plans
  where user_id = p_user_id
    and week_start = v_week_start
  order by created_at desc, id desc
  limit 1;

  if v_plan.id is null then
    insert into public.plans (user_id, week_start)
    values (p_user_id, v_week_start)
    returning * into v_plan;
  end if;

  return v_plan;
end;
$$;

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid references public.plans(id) on delete cascade,
  title text,
  description text,
  status text default 'pending',
  created_at timestamp default now(),
  updated_at timestamp default now(),
  proof_image text,
  scheduled_at timestamp with time zone,
  task_category text,
  archived_at timestamp with time zone
);

alter table public.plan_items
  add column if not exists description text,
  add column if not exists created_at timestamp default now(),
  add column if not exists updated_at timestamp default now(),
  add column if not exists scheduled_at timestamp with time zone,
  add column if not exists task_category text,
  add column if not exists archived_at timestamp with time zone;

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

update public.plan_items
set archived_at = null
where archived_at is not null;

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

create or replace function public._behavior_block_plan_item_status_mutation()
returns trigger
language plpgsql
as $$
begin
  if not public._behavior_can_write_projection() and new.status is distinct from old.status then
    raise exception 'plan_items.status is derived' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists plan_items_block_status_mutation on public.plan_items;
create trigger plan_items_block_status_mutation
before update on public.plan_items
for each row execute function public._behavior_block_plan_item_status_mutation();

drop trigger if exists plan_items_archive_on_delete on public.plan_items;
create or replace function public._behavior_archive_plan_item()
returns trigger
language plpgsql
as $$
begin
  if public._behavior_is_maintenance_actor() then
    return old;
  end if;

  update public.plan_items
  set archived_at = now(),
      updated_at = now()
  where id = old.id;

  return null;
end;
$$;

create trigger plan_items_archive_on_delete
before delete on public.plan_items
for each row execute function public._behavior_archive_plan_item();

alter table public.task_activity
  drop constraint if exists task_activity_task_id_fkey;

alter table public.task_activity
  add constraint task_activity_task_id_fkey
  foreign key (task_id) references public.plan_items(id) on delete set null not valid;

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
  new.request_key := lower(nullif(btrim(coalesce(new.request_key, '')), ''));

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
  request_key text,
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
  add column if not exists request_key text,
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

update public.messages
set request_key = lower(nullif(btrim(request_key), ''))
where request_key is not null;

create index if not exists idx_messages_conversation_id on public.messages(conversation_id);
create index if not exists idx_messages_conversation_created_at on public.messages(conversation_id, created_at desc);
create index if not exists idx_messages_sender_id on public.messages(sender_id);
create index if not exists idx_messages_receiver_id on public.messages(receiver_id);
create index if not exists idx_messages_created_at on public.messages(created_at desc);
create index if not exists idx_messages_unread_receiver on public.messages(receiver_id, conversation_id, created_at desc) where read_at is null and deleted_at is null;
create unique index if not exists idx_messages_request_key on public.messages(conversation_id, request_key) where request_key is not null;

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
  p_metadata jsonb default '{}'::jsonb,
  p_request_key text default null
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
  v_request_key text := lower(nullif(btrim(coalesce(p_request_key, '')), ''));
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

  if v_request_key is null then
    raise exception 'Request key is required' using errcode = '23502';
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

  select *
  into v_message
  from public.messages
  where conversation_id = p_conversation_id
    and request_key = v_request_key
  limit 1;

  if v_message.id is not null then
    return v_message;
  end if;

  v_receiver_id := case
    when v_current_user_id = v_conversation.client_id then v_conversation.coach_id
    else v_conversation.client_id
  end;

  begin
    insert into public.messages (
      conversation_id,
      sender_id,
      receiver_id,
      sender_role,
      message_type,
      content,
      text,
      metadata,
      request_key
    )
    values (
      p_conversation_id,
      v_current_user_id,
      v_receiver_id,
      v_sender_role,
      v_message_type,
      btrim(p_content),
      btrim(p_content),
      coalesce(p_metadata, '{}'::jsonb),
      v_request_key
    )
    returning * into v_message;
  exception
    when unique_violation then
      select *
      into v_message
      from public.messages
      where conversation_id = p_conversation_id
        and request_key = v_request_key
      limit 1;

      if v_message.id is null then
        raise;
      end if;
  end;

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

grant usage on schema public to authenticated;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text, text, jsonb, text) to authenticated;
grant execute on function public.mark_conversation_messages_read(uuid) to authenticated;

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

-- Unified behavioral timeline (MVP foundation).
-- Raw source tables remain the source of truth; this layer is append-only read model.

create or replace function public._behavior_clean_text(p_text text)
returns text
language sql
immutable
as $$
  select nullif(btrim(regexp_replace(coalesce(p_text, ''), '[[:space:]]+', ' ', 'g')), '');
$$;

create or replace function public._behavior_actor_label(p_actor_type text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(p_actor_type, ''))
    when 'client' then 'Client'
    when 'coach' then 'Coach'
    when 'system' then 'System'
    when 'ai' then 'AI'
    when 'administrator' then 'Admin'
    else 'Actor'
  end;
$$;

create or replace function public._behavior_actor_type(p_actor_type text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(p_actor_type, ''))
    when 'user' then 'client'
    when 'client' then 'client'
    when 'coach' then 'coach'
    when 'system' then 'system'
    when 'ai' then 'ai'
    when 'administrator' then 'administrator'
    when 'admin' then 'administrator'
    else 'client'
  end;
$$;

create or replace function public._behavior_parse_uuid(p_text text)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uuid uuid;
begin
  begin
    v_uuid := nullif(btrim(coalesce(p_text, '')), '')::uuid;
  exception when invalid_text_representation then
    return null;
  end;

  return v_uuid;
end;
$$;

create or replace function public._behavior_jsonb_uuid(p_data jsonb, p_key text)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public._behavior_parse_uuid(p_data ->> p_key);
$$;

create or replace function public._behavior_task_event_type(
  p_event_type text,
  p_completed boolean default false,
  p_skipped boolean default false
)
returns text
language sql
immutable
as $$
  select case lower(coalesce(nullif(btrim(p_event_type), ''), ''))
    when 'task_created' then 'task_created'
    when 'task_completed' then 'task_completed'
    when 'task_skipped' then 'task_skipped'
    when 'task_reopened' then 'task_reopened'
    when 'task_auto_closed' then 'task_auto_closed'
    when 'coach_recommended_task' then 'coach_recommended_task'
    when 'created' then 'task_created'
    when 'completed' then 'task_completed'
    when 'skipped' then 'task_skipped'
    when 'reopened' then 'task_reopened'
    when 'auto_closed' then 'task_auto_closed'
    when 'coach_recommended_task' then 'coach_recommended_task'
    else case
      when coalesce(p_completed, false) then 'task_completed'
      when coalesce(p_skipped, false) then 'task_skipped'
      else null
    end
  end;
$$;

create or replace function public._behavior_message_event_type(p_message_type text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(nullif(btrim(p_message_type), ''), 'text'))
    when 'intervention' then 'intervention_sent'
    when 'reflection_prompt' then 'reflection_prompt_sent'
    when 'checkin_followup' then 'reengagement_prompt_sent'
    else 'message_sent'
  end;
$$;

create or replace function public._behavior_task_summary(
  p_event_type text,
  p_task_title text
)
returns text
language plpgsql
immutable
as $$
declare
  v_title text := public._behavior_clean_text(p_task_title);
  v_action text := case lower(coalesce(nullif(btrim(p_event_type), ''), ''))
    when 'task_created' then 'Created'
    when 'task_completed' then 'Completed'
    when 'task_skipped' then 'Skipped'
    when 'task_reopened' then 'Reopened'
    when 'task_auto_closed' then 'Auto-closed'
    when 'coach_recommended_task' then 'Coach recommended'
    else 'Task event'
  end;
begin
  if lower(coalesce(nullif(btrim(p_event_type), ''), '')) = 'coach_recommended_task' then
    if v_title is null then
      return 'Coach recommended task';
    end if;

    return format('%s %s task', v_action, v_title);
  end if;

  if v_action = 'Task event' then
    if v_title is null then
      return 'Task event';
    end if;

    return format('%s for %s', v_action, v_title);
  end if;

  if v_title is null then
    return format('%s task', v_action);
  end if;

  return format('%s %s task', v_action, v_title);
end;
$$;

create or replace function public._behavior_task_status_from_event_type(p_event_type text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(nullif(btrim(p_event_type), ''), ''))
    when 'task_created' then 'pending'
    when 'task_completed' then 'done'
    when 'task_skipped' then 'pending'
    when 'task_reopened' then 'in_progress'
    when 'task_auto_closed' then 'pending'
    else null
  end;
$$;

create or replace function public._behavior_task_request_key(
  p_task_id uuid,
  p_action text,
  p_request_key text default null
)
returns text
language sql
immutable
as $$
  select lower(coalesce(nullif(btrim(p_request_key), ''), format('task:%s:%s', p_task_id, coalesce(nullif(btrim(p_action), ''), 'event'))));
$$;

create or replace function public._behavior_message_request_key(
  p_conversation_id uuid,
  p_message_type text,
  p_request_key text default null
)
returns text
language sql
immutable
as $$
  select lower(coalesce(nullif(btrim(p_request_key), ''), format('message:%s:%s', p_conversation_id, coalesce(nullif(btrim(p_message_type), ''), 'text'))));
$$;

create or replace function public._behavior_task_owner_id(p_task_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.user_id
  from public.plan_items pi
  join public.plans p on p.id = pi.plan_id
  where pi.id = p_task_id
  limit 1;
$$;

create or replace function public._behavior_is_maintenance_actor()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(current_user in ('postgres', 'service_role'), false)
    or coalesce(lower(coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '')), '') = 'service_role';
$$;

create or replace function public._behavior_can_write_projection()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public._behavior_is_maintenance_actor()
    or coalesce(current_setting('app.behavior_projection', true), '') = '1';
$$;

create or replace function public._behavior_checkin_summary(
  p_checkin_kind text,
  p_mood int,
  p_stress int,
  p_energy int,
  p_write_kind text default 'submitted'
)
returns text
language plpgsql
immutable
as $$
declare
  v_kind text := case lower(coalesce(nullif(btrim(p_checkin_kind), ''), 'daily'))
    when 'emotional' then 'emotional check-in'
    else 'daily check-in'
  end;
  v_action text := case lower(coalesce(nullif(btrim(p_write_kind), ''), 'submitted'))
    when 'updated' then 'Updated'
    when 'revised' then 'Revised'
    else 'Submitted'
  end;
begin
  return format('%s %s', v_action, v_kind);
end;
$$;

create or replace function public._behavior_personal_baseline_window(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when exists (
      select 1 from public.behavior_events be
      where be.primary_user_id = p_user_id
    ) then 14
    else 7
  end;
$$;

create or replace function public._behavior_latest_behavior_event(p_user_id uuid)
returns public.behavior_events
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select be.*
  from public.behavior_events be
  where be.primary_user_id = p_user_id
  order by be.occurred_at desc, be.id desc
  limit 1;
$$;

create or replace function public._behavior_count_events(
  p_user_id uuid,
  p_event_family text default null,
  p_event_type text default null,
  p_since timestamp with time zone default null,
  p_actor_type text default null
)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*)::bigint
  from public.behavior_events be
  where be.primary_user_id = p_user_id
    and (p_event_family is null or be.event_family = lower(p_event_family))
    and (p_event_type is null or be.event_type = lower(p_event_type))
    and (p_actor_type is null or be.actor_type = lower(p_actor_type))
    and (p_since is null or be.occurred_at >= p_since);
$$;

create or replace function public.build_behavior_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_now timestamptz := now();
  v_baseline_days int := public._behavior_personal_baseline_window(p_user_id);
  v_window_7 timestamptz := v_now - interval '7 days';
  v_window_14 timestamptz := v_now - interval '14 days';
  v_latest_event public.behavior_events%rowtype;
  v_latest_checkin timestamptz;
  v_latest_task timestamptz;
  v_latest_message timestamptz;
  v_latest_coach_intervention timestamptz;
  v_total_events_7 bigint;
  v_checkins_7 bigint;
  v_tasks_done_7 bigint;
  v_tasks_skipped_7 bigint;
  v_messages_sent_7 bigint;
  v_messages_read_7 bigint;
  v_coach_messages_sent_7 bigint;
  v_coach_interventions_14 bigint;
  v_intervention_responses_14 bigint;
  v_intervention_created_14 bigint;
  v_silence_days int;
  v_last_response_at timestamptz;
  v_recent_positive_streak int;
  v_return_after_silence boolean := false;
  v_positive_momentum boolean := false;
  v_instability boolean := false;
  v_read_no_reply boolean := false;
  v_recent_intervention_no_response boolean := false;
  v_missed_checkin boolean := false;
  v_attention_state text := 'healthy';
  v_recommended_action text := 'no_action';
  v_priority_score numeric := 0;
  v_priority_level text := 'low';
  v_attention_reason text := '';
  v_last_known_status text;
  v_overall_progress_score int;
  v_engagement_level int;
  v_consistency_streak int;
  v_days_since_last_activity int;
  v_snapshot jsonb;
begin
  select *
  into v_latest_event
  from public._behavior_latest_behavior_event(p_user_id) be;

  select max(occurred_at)
  into v_latest_checkin
  from public.behavior_events
  where primary_user_id = p_user_id
    and event_family = 'checkin';

  select max(occurred_at)
  into v_latest_task
  from public.behavior_events
  where primary_user_id = p_user_id
    and event_family = 'task';

  select max(occurred_at)
  into v_latest_message
  from public.behavior_events
  where primary_user_id = p_user_id
    and event_family = 'message';

  select max(ci.created_at)
  into v_latest_coach_intervention
  from public.coach_interventions ci
  where ci.user_id = p_user_id;

  select count(*)
  into v_total_events_7
  from public.behavior_events be
  where be.primary_user_id = p_user_id
    and be.occurred_at >= v_window_7;

  v_checkins_7 := public._behavior_count_events(p_user_id, 'checkin', null, v_window_7);
  v_tasks_done_7 := public._behavior_count_events(p_user_id, 'task', 'task_completed', v_window_7);
  v_tasks_skipped_7 := public._behavior_count_events(p_user_id, 'task', 'task_skipped', v_window_7);
  v_messages_sent_7 := public._behavior_count_events(p_user_id, 'message', 'message_sent', v_window_7, 'client');
  v_messages_read_7 := public._behavior_count_events(p_user_id, 'message', 'message_read', v_window_7, 'client');
  v_coach_messages_sent_7 := public._behavior_count_events(p_user_id, 'message', 'message_sent', v_window_7, 'coach');
  v_intervention_created_14 := public._behavior_count_events(p_user_id, 'intervention', 'intervention_created', v_window_14, 'coach');
  v_intervention_responses_14 := public._behavior_count_events(p_user_id, 'intervention', 'intervention_responded', v_window_14, 'client');

  select max(ci.responded_at)
  into v_last_response_at
  from public.coach_interventions ci
  where ci.user_id = p_user_id
    and ci.responded_at is not null;

  if v_latest_event.id is null then
    v_silence_days := v_baseline_days;
  else
    v_silence_days := greatest(0, (v_now::date - v_latest_event.occurred_at::date));
  end if;

  v_recent_positive_streak := 0;
  if v_latest_event.event_type in ('task_completed', 'checkin_submitted', 'message_sent') then
    v_recent_positive_streak := 1;
  end if;

  v_return_after_silence := v_latest_event.event_type in ('task_completed', 'checkin_submitted', 'message_sent') and v_silence_days >= 3;
  v_positive_momentum := v_tasks_done_7 >= 3 or v_checkins_7 >= 3;
  v_instability := v_tasks_skipped_7 >= 2 and v_silence_days >= 2;
  v_read_no_reply := v_coach_messages_sent_7 > 0 and v_messages_sent_7 = 0 and v_messages_read_7 > 0 and v_silence_days >= 2;
  v_recent_intervention_no_response := v_intervention_created_14 > v_intervention_responses_14 and v_intervention_created_14 > 0;
  v_missed_checkin := v_checkins_7 = 0 and v_silence_days >= 2;

  v_overall_progress_score := coalesce(
    (select u.progress_score from public.users u where u.id = p_user_id limit 1),
    0
  );
  v_engagement_level := coalesce(
    (select u.engagement_level from public.users u where u.id = p_user_id limit 1),
    0
  );
  v_consistency_streak := coalesce(
    (select u.consistency_streak from public.users u where u.id = p_user_id limit 1),
    0
  );
  v_days_since_last_activity := v_silence_days;
  v_last_known_status := coalesce(
    (select u.progress_status from public.users u where u.id = p_user_id limit 1),
    'onboarding'
  );

  if v_return_after_silence then
    v_attention_state := 'recovery_in_progress';
    v_recommended_action := 'celebrate_progress';
    v_priority_level := 'medium';
    v_attention_reason := 'Return after silence with a meaningful action.';
  elsif v_silence_days >= 10 then
    v_attention_state := 'high_risk_silence';
    v_recommended_action := 'soft_checkin';
    v_priority_level := 'high';
    v_priority_score := 82;
    v_attention_reason := 'Extended silence beyond the personal baseline window.';
  elsif v_instability then
    v_attention_state := 'needs_support';
    v_recommended_action := 'clarify_barrier';
    v_priority_level := 'medium';
    v_priority_score := 68;
    v_attention_reason := 'Repeated skipped tasks with low recent recovery signal.';
  elsif v_read_no_reply then
    v_attention_state := 'needs_support';
    v_recommended_action := 'soft_checkin';
    v_priority_level := 'medium';
    v_priority_score := 66;
    v_attention_reason := 'Messages were read, but there has not been a meaningful reply.';
  elsif v_recent_intervention_no_response then
    v_attention_state := 'needs_support';
    v_recommended_action := 'coach_followup';
    v_priority_level := 'medium';
    v_priority_score := 60;
    v_attention_reason := 'Recent intervention has not yet produced a response.';
  elsif v_missed_checkin then
    v_attention_state := 'disengaging';
    v_recommended_action := 'soft_checkin';
    v_priority_level := 'medium';
    v_priority_score := 58;
    v_attention_reason := 'Recent check-in signal is absent inside the personal rhythm window.';
  elsif v_positive_momentum then
    v_attention_state := 'momentum_growth';
    v_recommended_action := 'celebrate_progress';
    v_priority_level := 'low';
    v_priority_score := 28;
    v_attention_reason := 'Recent completion and check-in continuity indicate stable momentum.';
  elsif v_checkins_7 = 0 and v_tasks_done_7 = 0 and v_messages_sent_7 = 0 then
    v_attention_state := 'disengaging';
    v_recommended_action := 'soft_checkin';
    v_priority_level := 'medium';
    v_priority_score := 62;
    v_attention_reason := 'No meaningful activity inside the recent baseline window.';
  else
    v_attention_state := 'low_concern';
    v_recommended_action := 'no_action';
    v_priority_level := 'low';
    v_priority_score := 18;
    v_attention_reason := 'Behavior is currently within a low-concern range.';
  end if;

  if v_priority_score = 0 then
    v_priority_score := case v_priority_level
      when 'urgent' then 95
      when 'high' then 80
      when 'medium' then 55
      else 20
    end;
  end if;

  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'user_id', p_user_id,
    'attention_state', v_attention_state,
    'priority_level', v_priority_level,
    'priority_score', round(v_priority_score, 2),
    'recommended_action', v_recommended_action,
    'attention_reason', v_attention_reason,
    'last_event_at', v_latest_event.occurred_at,
    'last_event_type', v_latest_event.event_type,
    'last_event_family', v_latest_event.event_family,
    'latest_checkin_at', v_latest_checkin,
    'latest_task_at', v_latest_task,
    'latest_message_at', v_latest_message,
    'latest_coach_intervention_at', v_latest_coach_intervention,
    'silence_days', v_silence_days,
    'baseline_window_days', v_baseline_days,
    'total_events_7d', v_total_events_7,
    'checkins_7d', v_checkins_7,
    'tasks_done_7d', v_tasks_done_7,
    'tasks_skipped_7d', v_tasks_skipped_7,
    'messages_sent_7d', v_messages_sent_7,
    'messages_read_7d', v_messages_read_7,
    'coach_messages_sent_7d', v_coach_messages_sent_7,
    'coach_interventions_14d', v_coach_interventions_14,
    'intervention_responses_14d', v_intervention_responses_14,
    'intervention_created_14d', v_intervention_created_14,
    'return_after_silence', v_return_after_silence,
    'positive_momentum', v_positive_momentum,
    'instability', v_instability,
    'read_no_reply', v_read_no_reply,
    'recent_intervention_no_response', v_recent_intervention_no_response,
    'missed_checkin', v_missed_checkin,
    'progress_score', v_overall_progress_score,
    'engagement_level', v_engagement_level,
    'consistency_streak', v_consistency_streak,
    'days_since_last_activity', v_days_since_last_activity,
    'last_known_status', v_last_known_status,
    'last_response_at', v_last_response_at
  ));

  return v_snapshot;
end;
$$;

create or replace function public.calculate_user_attention_score(p_user_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_snapshot jsonb;
  v_score numeric := 0;
  v_silence_days int := 0;
  v_tasks_skipped_7d bigint := 0;
  v_checkins_7d bigint := 0;
  v_return_after_silence boolean := false;
  v_positive_momentum boolean := false;
  v_instability boolean := false;
begin
  v_snapshot := public.build_behavior_snapshot(p_user_id);

  v_silence_days := coalesce((v_snapshot ->> 'silence_days')::int, 0);
  v_tasks_skipped_7d := coalesce((v_snapshot ->> 'tasks_skipped_7d')::bigint, 0);
  v_checkins_7d := coalesce((v_snapshot ->> 'checkins_7d')::bigint, 0);
  v_return_after_silence := coalesce((v_snapshot ->> 'return_after_silence')::boolean, false);
  v_positive_momentum := coalesce((v_snapshot ->> 'positive_momentum')::boolean, false);
  v_instability := coalesce((v_snapshot ->> 'instability')::boolean, false);

  v_score := case
    when v_return_after_silence then 40
    when v_silence_days >= 10 then 88
    when v_instability then 72
    when v_positive_momentum then 24
    when v_checkins_7d = 0 and v_tasks_skipped_7d >= 2 then 64
    when v_silence_days >= 5 then 55
    else 16
  end;

  return greatest(0, least(100, round(v_score, 2)));
end;
$$;

create or replace function public.evaluate_coach_workqueue()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_coach record;
  v_client record;
  v_snapshot jsonb;
  v_priority_score numeric;
  v_priority_level text;
  v_queue_state text;
  v_attention_reason text;
  v_recommended_action text;
  v_latest_event public.behavior_events%rowtype;
  v_source_event_id uuid;
  v_source_event_type text;
  v_now timestamptz := now();
begin
  for v_coach in
    select u.id
    from public.users u
    where coalesce(u.role, 'client') = 'coach'
  loop
    for v_client in
      select c.user_id
      from public.clients c
      where c.coach_id = v_coach.id
    loop
      v_snapshot := public.build_behavior_snapshot(v_client.user_id);
      v_priority_score := coalesce((v_snapshot ->> 'priority_score')::numeric, 0);
      v_priority_level := coalesce(v_snapshot ->> 'priority_level', 'low');
      v_attention_reason := coalesce(v_snapshot ->> 'attention_reason', '');
      v_recommended_action := coalesce(v_snapshot ->> 'recommended_action', 'no_action');
      v_queue_state := case
        when v_priority_level = 'low' and v_recommended_action = 'no_action' then 'resolved'
        else 'active'
      end;

      select *
      into v_latest_event
      from public._behavior_latest_behavior_event(v_client.user_id);

      v_source_event_id := v_latest_event.id;
      v_source_event_type := v_latest_event.event_type;

      insert into public.coach_workqueue_items (
        coach_id,
        user_id,
        priority_score,
        priority_level,
        queue_state,
        attention_reason,
        recommended_action,
        behavior_snapshot,
        metadata,
        source_event_id,
        source_event_type,
        created_at,
        updated_at,
        resolved_at,
        last_evaluated_at
      )
      values (
        v_coach.id,
        v_client.user_id,
        v_priority_score,
        v_priority_level,
        v_queue_state,
        v_attention_reason,
        v_recommended_action,
        v_snapshot,
        jsonb_strip_nulls(jsonb_build_object(
          'attention_state', v_snapshot ->> 'attention_state',
          'priority_score', v_priority_score,
          'priority_level', v_priority_level,
          'recommended_action', v_recommended_action,
          'last_event_type', v_snapshot ->> 'last_event_type',
          'last_event_at', v_snapshot ->> 'last_event_at',
          'silence_days', v_snapshot ->> 'silence_days',
          'score_basis', jsonb_build_object(
            'checkins_7d', v_snapshot ->> 'checkins_7d',
            'tasks_done_7d', v_snapshot ->> 'tasks_done_7d',
            'tasks_skipped_7d', v_snapshot ->> 'tasks_skipped_7d',
            'messages_sent_7d', v_snapshot ->> 'messages_sent_7d',
            'positive_momentum', v_snapshot ->> 'positive_momentum',
            'return_after_silence', v_snapshot ->> 'return_after_silence'
          )
        )),
        jsonb_strip_nulls(jsonb_build_object(
          'evaluated_at', v_now,
          'baseline_window_days', v_snapshot ->> 'baseline_window_days',
          'progress_score', v_snapshot ->> 'progress_score',
          'engagement_level', v_snapshot ->> 'engagement_level',
          'consistency_streak', v_snapshot ->> 'consistency_streak',
          'days_since_last_activity', v_snapshot ->> 'days_since_last_activity'
        )),
        v_source_event_id,
        v_source_event_type,
        v_now,
        v_now,
        case when v_queue_state = 'resolved' then v_now else null end,
        v_now
      )
      on conflict (coach_id, user_id) do update
      set priority_score = excluded.priority_score,
          priority_level = excluded.priority_level,
          queue_state = excluded.queue_state,
          attention_reason = excluded.attention_reason,
          recommended_action = excluded.recommended_action,
          behavior_snapshot = excluded.behavior_snapshot,
          metadata = excluded.metadata,
          source_event_id = excluded.source_event_id,
          source_event_type = excluded.source_event_type,
          updated_at = v_now,
          resolved_at = case
            when excluded.queue_state = 'resolved' then coalesce(public.coach_workqueue_items.resolved_at, v_now)
            when excluded.queue_state in ('active', 'snoozed') then null
            else public.coach_workqueue_items.resolved_at
          end,
          last_evaluated_at = v_now;
    end loop;
  end loop;
end;
$$;

comment on function public.calculate_user_attention_score(uuid) is 'Rule-based attention score used to route coach attention; higher means more timely support is needed.';
comment on function public.build_behavior_snapshot(uuid) is 'Explainable behavioral snapshot built from timeline and source tables.';
comment on function public.evaluate_coach_workqueue() is 'Upserts coach workqueue state for all coach-client pairs using explainable rules.';

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('evaluate_coach_workqueue_hourly');
    perform cron.schedule(
      'evaluate_coach_workqueue_hourly',
      '0 * * * *',
      'select public.evaluate_coach_workqueue();'
    );
  end if;
exception
  when undefined_function then
    null;
end;
$$;

create or replace function public._behavior_message_summary(
  p_event_type text,
  p_actor_type text,
  p_message_type text,
  p_counterparty_type text default null
)
returns text
language plpgsql
immutable
as $$
declare
  v_actor_label text := public._behavior_actor_label(p_actor_type);
  v_counterparty_label text := public._behavior_actor_label(p_counterparty_type);
  v_message_kind text := case lower(coalesce(nullif(btrim(p_message_type), ''), 'text'))
    when 'intervention' then 'intervention'
    when 'reflection_prompt' then 'reflection prompt'
    when 'checkin_followup' then 're-engagement prompt'
    when 'coach_note' then 'note'
    when 'system' then 'message'
    when 'ai' then 'message'
    else 'message'
  end;
begin
  case lower(coalesce(nullif(btrim(p_event_type), ''), 'message_sent'))
    when 'message_read' then
      if p_counterparty_type is null then
        return format('%s read %s', v_actor_label, v_message_kind);
      end if;

      return format('%s read %s %s', v_actor_label, v_counterparty_label, v_message_kind);
    when 'intervention_sent' then
      return format('%s sent an intervention', v_actor_label);
    when 'reflection_prompt_sent' then
      return format('%s sent a reflection prompt', v_actor_label);
    when 'reengagement_prompt_sent' then
      return format('%s sent a re-engagement prompt', v_actor_label);
    when 'message_sent' then
      if lower(coalesce(nullif(btrim(p_message_type), ''), 'text')) = 'coach_note' then
        return format('%s note added', v_actor_label);
      elsif lower(coalesce(nullif(btrim(p_message_type), ''), 'text')) = 'system' then
        return format('%s message sent', v_actor_label);
      elsif lower(coalesce(nullif(btrim(p_message_type), ''), 'text')) = 'ai' then
        return format('%s message sent', v_actor_label);
      end if;

      return format('%s sent a message', v_actor_label);
    else
      return format('%s message event', v_actor_label);
  end case;
end;
$$;

create table if not exists public.behavior_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamp with time zone not null default now(),
  primary_user_id uuid not null references public.users(id) on delete cascade,
  actor_type text not null,
  actor_id uuid references public.users(id) on delete set null,
  event_family text not null,
  event_type text not null,
  origin_kind text not null default 'raw',
  source_table text not null,
  source_id uuid not null,
  source_event_key text not null,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  correlation_id uuid,
  causation_id uuid,
  visibility_scope text not null default 'both',
  schema_version int not null default 1,
  created_at timestamp with time zone not null default now()
);

alter table public.behavior_events
  add column if not exists occurred_at timestamp with time zone not null default now(),
  add column if not exists primary_user_id uuid references public.users(id) on delete cascade,
  add column if not exists actor_type text,
  add column if not exists actor_id uuid references public.users(id) on delete set null,
  add column if not exists event_family text,
  add column if not exists event_type text,
  add column if not exists origin_kind text default 'raw',
  add column if not exists source_table text,
  add column if not exists source_id uuid,
  add column if not exists source_event_key text,
  add column if not exists summary text,
  add column if not exists metadata jsonb default '{}'::jsonb,
  add column if not exists correlation_id uuid,
  add column if not exists causation_id uuid,
  add column if not exists visibility_scope text default 'both',
  add column if not exists schema_version int default 1,
  add column if not exists created_at timestamp with time zone not null default now();

alter table public.behavior_events
  alter column occurred_at set default now(),
  alter column primary_user_id set not null,
  alter column origin_kind set default 'raw',
  alter column metadata set default '{}'::jsonb,
  alter column visibility_scope set default 'both',
  alter column schema_version set default 1,
  alter column created_at set default now();

alter table public.behavior_events
  drop constraint if exists behavior_events_actor_type_check;

alter table public.behavior_events
  add constraint behavior_events_actor_type_check
  check (actor_type in ('client', 'coach', 'system', 'ai', 'administrator'));

alter table public.behavior_events
  drop constraint if exists behavior_events_actor_id_check;

alter table public.behavior_events
  add constraint behavior_events_actor_id_check
  check (
    actor_type in ('system', 'ai')
    or actor_id is not null
  );

alter table public.behavior_events
  drop constraint if exists behavior_events_event_family_check;

alter table public.behavior_events
  add constraint behavior_events_event_family_check
  check (event_family in ('task', 'message', 'checkin', 'intervention', 'system'));

alter table public.behavior_events
  drop constraint if exists behavior_events_event_type_check;

alter table public.behavior_events
  add constraint behavior_events_event_type_check
  check (
    event_type in (
      'task_created',
      'task_completed',
      'task_skipped',
      'task_reopened',
      'task_auto_closed',
      'coach_recommended_task',
      'message_sent',
      'message_read',
      'intervention_created',
      'intervention_responded',
      'intervention_expired',
      'intervention_sent',
      'reflection_prompt_sent',
      'reengagement_prompt_sent',
      'checkin_submitted',
      'emotional_checkin_submitted',
      'streak_changed',
      'intervention_triggered',
      'risk_flagged'
    )
  );

alter table public.behavior_events
  drop constraint if exists behavior_events_origin_kind_check;

alter table public.behavior_events
  add constraint behavior_events_origin_kind_check
  check (origin_kind in ('raw', 'derived'));

alter table public.behavior_events
  drop constraint if exists behavior_events_visibility_scope_check;

alter table public.behavior_events
  add constraint behavior_events_visibility_scope_check
  check (visibility_scope in ('both', 'owner', 'coach', 'system'));

alter table public.behavior_events
  drop constraint if exists behavior_events_metadata_object_check;

alter table public.behavior_events
  add constraint behavior_events_metadata_object_check
  check (metadata is not null and jsonb_typeof(metadata) = 'object');

alter table public.behavior_events
  drop constraint if exists behavior_events_summary_not_blank_check;

alter table public.behavior_events
  add constraint behavior_events_summary_not_blank_check
  check (btrim(summary) <> '');

alter table public.behavior_events
  drop constraint if exists behavior_events_source_table_not_blank_check;

alter table public.behavior_events
  add constraint behavior_events_source_table_not_blank_check
  check (btrim(source_table) <> '');

alter table public.behavior_events
  drop constraint if exists behavior_events_source_event_key_not_blank_check;

alter table public.behavior_events
  add constraint behavior_events_source_event_key_not_blank_check
  check (btrim(source_event_key) <> '');

alter table public.behavior_events
  drop constraint if exists behavior_events_schema_version_check;

alter table public.behavior_events
  add constraint behavior_events_schema_version_check
  check (schema_version > 0);

create unique index if not exists idx_behavior_events_source_event_key on public.behavior_events(source_event_key);
create index if not exists idx_behavior_events_primary_user_occurred_at on public.behavior_events(primary_user_id, occurred_at desc, id desc);
create index if not exists idx_behavior_events_primary_user_family_occurred_at on public.behavior_events(primary_user_id, event_family, occurred_at desc, id desc);
create index if not exists idx_behavior_events_source_lookup on public.behavior_events(source_table, source_id);
create index if not exists idx_behavior_events_correlation_id on public.behavior_events(correlation_id);
create index if not exists idx_behavior_events_causation_id on public.behavior_events(causation_id);

alter table public.behavior_events
  enable row level security;

drop policy if exists "behavior_events_select_owner_or_coach" on public.behavior_events;

create policy "behavior_events_select_owner_or_coach"
on public.behavior_events
for select
to authenticated
using (
  (
    primary_user_id = auth.uid()
    and visibility_scope in ('both', 'owner')
  )
  or (
    visibility_scope in ('both', 'coach')
    and public._behavior_is_coach_for_user(primary_user_id)
  )
);

create or replace function public._behavior_block_behavior_event_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'behavior_events is append-only' using errcode = '42501';
end;
$$;

drop trigger if exists behavior_events_block_update on public.behavior_events;

create trigger behavior_events_block_update
before update on public.behavior_events
for each row execute function public._behavior_block_behavior_event_mutation();

drop trigger if exists behavior_events_block_delete on public.behavior_events;

create trigger behavior_events_block_delete
before delete on public.behavior_events
for each row execute function public._behavior_block_behavior_event_mutation();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.behavior_events;
    exception when duplicate_object then
      null;
    end;
  end if;
end;
$$;

create or replace function public._behavior_store_event(
  p_primary_user_id uuid,
  p_actor_type text,
  p_actor_id uuid,
  p_event_family text,
  p_event_type text,
  p_origin_kind text,
  p_source_table text,
  p_source_id uuid,
  p_source_event_key text,
  p_summary text,
  p_metadata jsonb default '{}'::jsonb,
  p_correlation_id uuid default null,
  p_causation_id uuid default null,
  p_visibility_scope text default 'both',
  p_occurred_at timestamp with time zone default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_event_id uuid;
  v_actor_type text := lower(coalesce(nullif(btrim(coalesce(p_actor_type, '')), ''), 'client'));
  v_event_family text := lower(coalesce(nullif(btrim(coalesce(p_event_family, '')), ''), ''));
  v_event_type text := lower(coalesce(nullif(btrim(coalesce(p_event_type, '')), ''), ''));
  v_origin_kind text := lower(coalesce(nullif(btrim(coalesce(p_origin_kind, '')), ''), 'raw'));
  v_source_table text := lower(coalesce(nullif(btrim(coalesce(p_source_table, '')), ''), ''));
  v_source_event_key text := lower(coalesce(nullif(btrim(coalesce(p_source_event_key, '')), ''), ''));
  v_summary text := coalesce(public._behavior_clean_text(p_summary), 'Behavior event recorded');
  v_visibility_scope text := lower(coalesce(nullif(btrim(coalesce(p_visibility_scope, '')), ''), 'both'));
  v_metadata jsonb := jsonb_strip_nulls(coalesce(p_metadata, '{}'::jsonb));
begin
  if p_primary_user_id is null
     or p_source_id is null
     or v_source_table = ''
     or v_source_event_key = ''
     or v_event_family = ''
     or v_event_type = '' then
    return null;
  end if;

  if v_actor_type not in ('client', 'coach', 'system', 'ai', 'administrator') then
    return null;
  end if;

  if v_actor_type not in ('system', 'ai') and p_actor_id is null then
    return null;
  end if;

  if v_event_family not in ('task', 'message', 'checkin', 'intervention', 'system') then
    return null;
  end if;

  if v_event_type not in (
    'task_created',
    'task_completed',
    'task_skipped',
    'task_reopened',
    'task_auto_closed',
    'coach_recommended_task',
    'message_sent',
    'message_read',
    'intervention_created',
    'intervention_responded',
    'intervention_expired',
    'intervention_sent',
    'reflection_prompt_sent',
    'reengagement_prompt_sent',
    'checkin_submitted',
    'emotional_checkin_submitted',
    'streak_changed',
    'intervention_triggered',
    'risk_flagged'
  ) then
    return null;
  end if;

  if v_origin_kind not in ('raw', 'derived') then
    v_origin_kind := 'raw';
  end if;

  if v_visibility_scope not in ('both', 'owner', 'coach', 'system') then
    v_visibility_scope := 'both';
  end if;

  if jsonb_typeof(v_metadata) <> 'object' then
    v_metadata := '{}'::jsonb;
  end if;

  insert into public.behavior_events (
    occurred_at,
    primary_user_id,
    actor_type,
    actor_id,
    event_family,
    event_type,
    origin_kind,
    source_table,
    source_id,
    source_event_key,
    summary,
    metadata,
    correlation_id,
    causation_id,
    visibility_scope
  )
  values (
    coalesce(p_occurred_at, now()),
    p_primary_user_id,
    v_actor_type,
    p_actor_id,
    v_event_family,
    v_event_type,
    v_origin_kind,
    v_source_table,
    p_source_id,
    v_source_event_key,
    v_summary,
    v_metadata,
    p_correlation_id,
    p_causation_id,
    v_visibility_scope
  )
  on conflict (source_event_key) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    select be.id
    into v_event_id
    from public.behavior_events be
    where be.source_event_key = v_source_event_key
    limit 1;
  end if;

  return v_event_id;
end;
$$;

create or replace function public._behavior_ingest_task_activity_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_primary_user_id uuid;
  v_plan_id uuid;
  v_task_title text;
  v_actor_type text := public._behavior_actor_type(coalesce(new.event_source, 'user'));
  v_actor_id uuid;
  v_event_type text := public._behavior_task_event_type(new.event_type, new.completed, new.skipped);
  v_source_metadata jsonb := coalesce(new.metadata, '{}'::jsonb);
  v_trigger text := public._behavior_clean_text(v_source_metadata ->> 'trigger');
  v_reason_code text := public._behavior_clean_text(v_source_metadata ->> 'reason_code');
  v_summary text;
  v_metadata jsonb;
  v_correlation_id uuid;
  v_causation_id uuid;
begin
  select p.user_id, p.id, public._behavior_clean_text(pi.title)
  into v_primary_user_id, v_plan_id, v_task_title
  from public.plan_items pi
  join public.plans p on p.id = pi.plan_id
  where pi.id = new.task_id
  limit 1;

  if v_primary_user_id is null then
    v_primary_user_id := new.user_id;
  end if;

  if v_primary_user_id is null or v_event_type is null then
    return new;
  end if;

  v_actor_id := new.user_id;

  if v_actor_type = 'coach' then
    select c.coach_id
    into v_actor_id
    from public.clients c
    where c.user_id = v_primary_user_id
    limit 1;
  elsif v_actor_type in ('system', 'ai') then
    v_actor_id := null;
  end if;

  v_correlation_id := public._behavior_jsonb_uuid(v_source_metadata, 'correlation_id');
  v_causation_id := public._behavior_jsonb_uuid(v_source_metadata, 'causation_id');

  v_metadata := jsonb_strip_nulls(jsonb_build_object(
    'task_activity_id', new.id,
    'task_id', new.task_id,
    'plan_id', v_plan_id,
    'task_title', v_task_title,
    'event_source', public._behavior_actor_type(coalesce(new.event_source, 'user')),
    'source_event_type', public._behavior_clean_text(new.event_type),
    'completed', new.completed,
    'skipped', new.skipped,
    'trigger', v_trigger,
    'reason_code', v_reason_code
  ));

  v_summary := public._behavior_task_summary(v_event_type, v_task_title);

  perform public._behavior_store_event(
    p_primary_user_id := v_primary_user_id,
    p_actor_type := v_actor_type,
    p_actor_id := v_actor_id,
    p_event_family := 'task',
    p_event_type := v_event_type,
    p_origin_kind := 'raw',
    p_source_table := 'task_activity',
    p_source_id := new.id,
    p_source_event_key := format('task_activity:%s', new.id),
    p_summary := v_summary,
    p_metadata := v_metadata,
    p_correlation_id := v_correlation_id,
    p_causation_id := v_causation_id,
    p_visibility_scope := 'both',
    p_occurred_at := coalesce(new.completed_at, new.updated_at, new.created_at, now())
  );

  return new;
end;
$$;

drop trigger if exists task_activity_ingest_behavior_event on public.task_activity;

create trigger task_activity_ingest_behavior_event
after insert on public.task_activity
for each row execute function public._behavior_ingest_task_activity_event();

create or replace function public._behavior_ingest_check_in_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_type text := public._behavior_actor_type('client');
  v_checkin_kind text := 'daily';
  v_write_kind text := lower(coalesce(tg_op, 'insert'));
  v_stress int := coalesce(new.stress, new.stress_level);
  v_energy int := coalesce(new.energy, new.energy_level);
  v_summary text;
  v_metadata jsonb;
begin
  if new.user_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and not (
       new.date is distinct from old.date
       or new.mood is distinct from old.mood
       or new.stress is distinct from old.stress
       or new.stress_level is distinct from old.stress_level
       or new.energy is distinct from old.energy
       or new.energy_level is distinct from old.energy_level
     ) then
    return new;
  end if;

  select public._behavior_actor_type(coalesce(role, 'client'))
  into v_actor_type
  from public.users
  where id = new.user_id
  limit 1;

  if v_actor_type is null then
    v_actor_type := 'client';
  end if;

  v_metadata := jsonb_strip_nulls(jsonb_build_object(
    'checkin_id', new.id,
    'checkin_date', new.date,
    'checkin_kind', v_checkin_kind,
    'write_kind', v_write_kind,
    'mood', new.mood,
    'stress', v_stress,
    'energy', v_energy
  ));

  v_summary := public._behavior_checkin_summary(v_checkin_kind, new.mood, v_stress, v_energy, v_write_kind);

  if tg_op = 'INSERT' then
    perform public._behavior_store_event(
      p_primary_user_id := new.user_id,
      p_actor_type := v_actor_type,
      p_actor_id := new.user_id,
      p_event_family := 'checkin',
      p_event_type := 'checkin_submitted',
      p_origin_kind := 'raw',
      p_source_table := 'check_ins',
      p_source_id := new.id,
      p_source_event_key := format('check_ins:%s:submitted', new.id),
      p_summary := v_summary,
      p_metadata := v_metadata,
      p_visibility_scope := 'both',
      p_occurred_at := coalesce(new.created_at, new.updated_at, now())
    );

    return new;
  end if;

  perform public._behavior_store_event(
    p_primary_user_id := new.user_id,
    p_actor_type := v_actor_type,
    p_actor_id := new.user_id,
    p_event_family := 'checkin',
    p_event_type := 'checkin_submitted',
    p_origin_kind := 'raw',
    p_source_table := 'check_ins',
    p_source_id := new.id,
    p_source_event_key := format('check_ins:%s:submitted:%s', new.id, to_char(coalesce(new.updated_at, clock_timestamp()), 'YYYYMMDDHH24MISSUS')),
    p_summary := v_summary,
    p_metadata := v_metadata,
    p_visibility_scope := 'both',
    p_occurred_at := coalesce(new.created_at, new.updated_at, now())
  );

  return new;
end;
$$;

drop trigger if exists check_ins_ingest_behavior_event on public.check_ins;

create trigger check_ins_ingest_behavior_event
after insert or update of date, mood, stress, stress_level, energy, energy_level on public.check_ins
for each row execute function public._behavior_ingest_check_in_event();

create or replace function public._behavior_ingest_message_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_primary_user_id uuid;
  v_sender_role text := lower(coalesce(nullif(btrim(coalesce(new.sender_role, '')), ''), 'client'));
  v_message_type text := lower(coalesce(nullif(btrim(coalesce(new.message_type, '')), ''), 'text'));
  v_actor_type text := public._behavior_actor_type(v_sender_role);
  v_message_text text := public._behavior_clean_text(coalesce(new.content, new.text));
  v_summary text;
  v_metadata jsonb;
  v_correlation_id uuid;
  v_causation_id uuid;
begin
  select c.client_id
  into v_primary_user_id
  from public.conversations c
  where c.id = new.conversation_id
  limit 1;

  if v_primary_user_id is null and new.sender_id is not null and new.receiver_id is not null then
    select c.user_id
    into v_primary_user_id
    from public.clients c
    where (c.user_id = new.sender_id and c.coach_id = new.receiver_id)
       or (c.user_id = new.receiver_id and c.coach_id = new.sender_id)
    limit 1;
  end if;

  if v_primary_user_id is null then
    return new;
  end if;

  v_correlation_id := public._behavior_jsonb_uuid(coalesce(new.metadata, '{}'::jsonb), 'correlation_id');
  v_causation_id := public._behavior_jsonb_uuid(coalesce(new.metadata, '{}'::jsonb), 'causation_id');

  v_metadata := jsonb_strip_nulls(jsonb_build_object(
    'conversation_id', new.conversation_id,
    'message_id', new.id,
    'sender_id', new.sender_id,
    'receiver_id', new.receiver_id,
    'sender_role', v_sender_role,
    'message_type', v_message_type,
    'content_length', case when v_message_text is null then null else length(v_message_text) end,
    'message_preview', case when v_message_text is null then null else left(v_message_text, 120) end,
    'has_image', new.image_url is not null,
    'trigger', public._behavior_clean_text(new.metadata ->> 'trigger'),
    'template_key', public._behavior_clean_text(new.metadata ->> 'template_key'),
    'intervention_id', public._behavior_clean_text(new.metadata ->> 'intervention_id'),
    'prompt_id', public._behavior_clean_text(new.metadata ->> 'prompt_id')
  ));

  v_summary := public._behavior_message_summary(
    public._behavior_message_event_type(v_message_type),
    v_actor_type,
    v_message_type,
    null
  );

  perform public._behavior_store_event(
    p_primary_user_id := v_primary_user_id,
    p_actor_type := v_actor_type,
    p_actor_id := new.sender_id,
    p_event_family := 'message',
    p_event_type := public._behavior_message_event_type(v_message_type),
    p_origin_kind := 'raw',
    p_source_table := 'messages',
    p_source_id := new.id,
    p_source_event_key := format('messages:%s:sent', new.id),
    p_summary := v_summary,
    p_metadata := v_metadata,
    p_correlation_id := v_correlation_id,
    p_causation_id := v_causation_id,
    p_visibility_scope := 'both',
    p_occurred_at := coalesce(new.created_at, now())
  );

  return new;
end;
$$;

drop trigger if exists messages_ingest_behavior_event on public.messages;

create trigger messages_ingest_behavior_event
after insert on public.messages
for each row execute function public._behavior_ingest_message_event();

create or replace function public._behavior_ingest_message_read_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_primary_user_id uuid;
  v_reader_role text;
  v_actor_type text;
  v_sender_role text := lower(coalesce(nullif(btrim(coalesce(old.sender_role, '')), ''), 'client'));
  v_message_type text := lower(coalesce(nullif(btrim(coalesce(old.message_type, '')), ''), 'text'));
  v_summary text;
  v_metadata jsonb;
  v_correlation_id uuid;
  v_causation_id uuid;
  v_message_text text := public._behavior_clean_text(coalesce(old.content, old.text));
begin
  if old.read_at is not null or new.read_at is null then
    return new;
  end if;

  select c.client_id
  into v_primary_user_id
  from public.conversations c
  where c.id = new.conversation_id
  limit 1;

  if v_primary_user_id is null and new.sender_id is not null and new.receiver_id is not null then
    select c.user_id
    into v_primary_user_id
    from public.clients c
    where (c.user_id = new.sender_id and c.coach_id = new.receiver_id)
       or (c.user_id = new.receiver_id and c.coach_id = new.sender_id)
    limit 1;
  end if;

  if v_primary_user_id is null then
    return new;
  end if;

  select lower(coalesce(role, 'client'))
  into v_reader_role
  from public.users
  where id = new.receiver_id
  limit 1;

  v_actor_type := public._behavior_actor_type(coalesce(v_reader_role, 'client'));

  v_correlation_id := public._behavior_jsonb_uuid(coalesce(new.metadata, '{}'::jsonb), 'correlation_id');

  select be.id
  into v_causation_id
  from public.behavior_events be
  where be.source_event_key = format('messages:%s:sent', new.id)
  limit 1;

  v_metadata := jsonb_strip_nulls(jsonb_build_object(
    'conversation_id', new.conversation_id,
    'message_id', new.id,
    'sender_id', new.sender_id,
    'receiver_id', new.receiver_id,
    'sender_role', v_sender_role,
    'reader_role', v_reader_role,
    'message_type', v_message_type,
    'content_length', case when v_message_text is null then null else length(v_message_text) end,
    'message_preview', case when v_message_text is null then null else left(v_message_text, 120) end,
    'has_image', new.image_url is not null,
    'read_delay_seconds', case
      when new.read_at is null or new.created_at is null then null
      else greatest(0, floor(extract(epoch from (new.read_at - new.created_at))))::int
    end,
    'trigger', public._behavior_clean_text(new.metadata ->> 'trigger'),
    'template_key', public._behavior_clean_text(new.metadata ->> 'template_key')
  ));

  v_summary := public._behavior_message_summary(
    'message_read',
    v_actor_type,
    v_message_type,
    v_sender_role
  );

  perform public._behavior_store_event(
    p_primary_user_id := v_primary_user_id,
    p_actor_type := v_actor_type,
    p_actor_id := new.receiver_id,
    p_event_family := 'message',
    p_event_type := 'message_read',
    p_origin_kind := 'raw',
    p_source_table := 'messages',
    p_source_id := new.id,
    p_source_event_key := format('messages:%s:read', new.id),
    p_summary := v_summary,
    p_metadata := v_metadata,
    p_correlation_id := v_correlation_id,
    p_causation_id := v_causation_id,
    p_visibility_scope := 'both',
    p_occurred_at := coalesce(new.read_at, now())
  );

  return new;
end;
$$;

drop trigger if exists messages_ingest_behavior_read_event on public.messages;

create trigger messages_ingest_behavior_read_event
after update of read_at on public.messages
for each row execute function public._behavior_ingest_message_read_event();

insert into public.behavior_events (
  occurred_at,
  primary_user_id,
  actor_type,
  actor_id,
  event_family,
  event_type,
  origin_kind,
  source_table,
  source_id,
  source_event_key,
  summary,
  metadata,
  correlation_id,
  causation_id,
  visibility_scope,
  schema_version,
  created_at
)
with task_src as (
  select
    ta.id,
    ta.user_id,
    ta.task_id,
    ta.event_type,
    ta.event_source,
    ta.metadata,
    ta.completed,
    ta.skipped,
    ta.completed_at,
    ta.updated_at,
    ta.created_at,
    p.user_id as owner_id,
    p.id as plan_id,
    public._behavior_clean_text(pi.title) as task_title,
    public._behavior_task_event_type(ta.event_type, ta.completed, ta.skipped) as mapped_event_type,
    public._behavior_actor_type(coalesce(ta.event_source, 'user')) as mapped_actor_type,
    public._behavior_jsonb_uuid(coalesce(ta.metadata, '{}'::jsonb), 'correlation_id') as mapped_correlation_id,
    public._behavior_jsonb_uuid(coalesce(ta.metadata, '{}'::jsonb), 'causation_id') as mapped_causation_id
  from public.task_activity ta
  left join public.plan_items pi on pi.id = ta.task_id
  left join public.plans p on p.id = pi.plan_id
)
select
  coalesce(task_src.completed_at, task_src.updated_at, task_src.created_at, now()) as occurred_at,
  coalesce(task_src.owner_id, task_src.user_id) as primary_user_id,
  task_src.mapped_actor_type as actor_type,
  case
    when task_src.mapped_actor_type = 'coach' then coach_link.coach_id
    when task_src.mapped_actor_type in ('system', 'ai') then null
    else task_src.user_id
  end as actor_id,
  'task' as event_family,
  task_src.mapped_event_type as event_type,
  'raw' as origin_kind,
  'task_activity' as source_table,
  task_src.id as source_id,
  format('task_activity:%s', task_src.id) as source_event_key,
  public._behavior_task_summary(task_src.mapped_event_type, task_src.task_title) as summary,
  jsonb_strip_nulls(jsonb_build_object(
    'task_activity_id', task_src.id,
    'task_id', task_src.task_id,
    'plan_id', task_src.plan_id,
    'task_title', task_src.task_title,
    'event_source', public._behavior_actor_type(coalesce(task_src.event_source, 'user')),
    'source_event_type', public._behavior_clean_text(task_src.event_type),
    'completed', task_src.completed,
    'skipped', task_src.skipped
  )) as metadata,
  task_src.mapped_correlation_id as correlation_id,
  task_src.mapped_causation_id as causation_id,
  'both' as visibility_scope,
  1 as schema_version,
  now() as created_at
from task_src
left join public.clients coach_link
  on coach_link.user_id = task_src.owner_id
where task_src.mapped_event_type is not null
  and coalesce(task_src.owner_id, task_src.user_id) is not null
  and (
    task_src.mapped_actor_type in ('system', 'ai')
    or (task_src.mapped_actor_type = 'coach' and coach_link.coach_id is not null)
    or (task_src.mapped_actor_type in ('client', 'administrator') and task_src.user_id is not null)
  )
on conflict (source_event_key) do nothing;

insert into public.behavior_events (
  occurred_at,
  primary_user_id,
  actor_type,
  actor_id,
  event_family,
  event_type,
  origin_kind,
  source_table,
  source_id,
  source_event_key,
  summary,
  metadata,
  correlation_id,
  causation_id,
  visibility_scope,
  schema_version,
  created_at
)
with message_src as (
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    m.receiver_id,
    lower(coalesce(nullif(btrim(coalesce(m.sender_role, '')), ''), 'client')) as sender_role,
    lower(coalesce(nullif(btrim(coalesce(m.message_type, '')), ''), 'text')) as message_type,
    m.content,
    m.metadata,
    m.read_at,
    m.edited_at,
    m.deleted_at,
    m.text,
    m.image_url,
    m.created_at,
    c.client_id,
    public._behavior_actor_type(lower(coalesce(nullif(btrim(coalesce(m.sender_role, '')), ''), 'client'))) as mapped_sender_actor_type,
    public._behavior_actor_type(lower(coalesce(nullif(btrim(coalesce(u.role, '')), ''), 'client'))) as mapped_reader_actor_type,
    public._behavior_message_event_type(lower(coalesce(nullif(btrim(coalesce(m.message_type, '')), ''), 'text'))) as mapped_message_event_type,
    public._behavior_jsonb_uuid(coalesce(m.metadata, '{}'::jsonb), 'correlation_id') as mapped_correlation_id,
    public._behavior_jsonb_uuid(coalesce(m.metadata, '{}'::jsonb), 'causation_id') as mapped_causation_id
  from public.messages m
  left join public.conversations c on c.id = m.conversation_id
  left join public.users u on u.id = m.receiver_id
)
select
  coalesce(message_src.created_at, now()) as occurred_at,
  coalesce(message_src.client_id, message_src.sender_id, message_src.receiver_id) as primary_user_id,
  message_src.mapped_sender_actor_type as actor_type,
  message_src.sender_id as actor_id,
  'message' as event_family,
  message_src.mapped_message_event_type as event_type,
  'raw' as origin_kind,
  'messages' as source_table,
  message_src.id as source_id,
  format('messages:%s:sent', message_src.id) as source_event_key,
  public._behavior_message_summary(message_src.mapped_message_event_type, message_src.mapped_sender_actor_type, message_src.message_type, null) as summary,
  jsonb_strip_nulls(jsonb_build_object(
    'conversation_id', message_src.conversation_id,
    'message_id', message_src.id,
    'sender_id', message_src.sender_id,
    'receiver_id', message_src.receiver_id,
    'sender_role', message_src.sender_role,
    'message_type', message_src.message_type,
    'content_length', case when public._behavior_clean_text(coalesce(message_src.content, message_src.text)) is null then null else length(public._behavior_clean_text(coalesce(message_src.content, message_src.text))) end,
    'message_preview', case when public._behavior_clean_text(coalesce(message_src.content, message_src.text)) is null then null else left(public._behavior_clean_text(coalesce(message_src.content, message_src.text)), 120) end,
    'has_image', message_src.image_url is not null
  )) as metadata,
  message_src.mapped_correlation_id as correlation_id,
  message_src.mapped_causation_id as causation_id,
  'both' as visibility_scope,
  1 as schema_version,
  now() as created_at
from message_src
where message_src.mapped_message_event_type is not null
  and coalesce(message_src.client_id, message_src.sender_id, message_src.receiver_id) is not null
  and (
    message_src.mapped_sender_actor_type in ('system', 'ai')
    or message_src.sender_id is not null
  )
on conflict (source_event_key) do nothing;

insert into public.behavior_events (
  occurred_at,
  primary_user_id,
  actor_type,
  actor_id,
  event_family,
  event_type,
  origin_kind,
  source_table,
  source_id,
  source_event_key,
  summary,
  metadata,
  correlation_id,
  causation_id,
  visibility_scope,
  schema_version,
  created_at
)
with message_read_src as (
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    m.receiver_id,
    lower(coalesce(nullif(btrim(coalesce(m.sender_role, '')), ''), 'client')) as sender_role,
    lower(coalesce(nullif(btrim(coalesce(m.message_type, '')), ''), 'text')) as message_type,
    m.content,
    m.text,
    m.image_url,
    m.metadata,
    m.read_at,
    m.created_at,
    c.client_id,
    public._behavior_actor_type(lower(coalesce(nullif(btrim(coalesce(u.role, '')), ''), 'client'))) as mapped_reader_actor_type,
    public._behavior_jsonb_uuid(coalesce(m.metadata, '{}'::jsonb), 'correlation_id') as mapped_correlation_id
  from public.messages m
  left join public.conversations c on c.id = m.conversation_id
  left join public.users u on u.id = m.receiver_id
  where m.read_at is not null
)
select
  coalesce(message_read_src.read_at, now()) as occurred_at,
  coalesce(message_read_src.client_id, message_read_src.sender_id, message_read_src.receiver_id) as primary_user_id,
  message_read_src.mapped_reader_actor_type as actor_type,
  message_read_src.receiver_id as actor_id,
  'message' as event_family,
  'message_read' as event_type,
  'raw' as origin_kind,
  'messages' as source_table,
  message_read_src.id as source_id,
  format('messages:%s:read', message_read_src.id) as source_event_key,
  public._behavior_message_summary('message_read', message_read_src.mapped_reader_actor_type, message_read_src.message_type, message_read_src.sender_role) as summary,
  jsonb_strip_nulls(jsonb_build_object(
    'conversation_id', message_read_src.conversation_id,
    'message_id', message_read_src.id,
    'sender_id', message_read_src.sender_id,
    'receiver_id', message_read_src.receiver_id,
    'sender_role', message_read_src.sender_role,
    'reader_role', lower(coalesce(nullif(btrim(coalesce((select u.role from public.users u where u.id = message_read_src.receiver_id limit 1), '')), ''), 'client')),
    'message_type', message_read_src.message_type,
    'content_length', case when public._behavior_clean_text(coalesce(message_read_src.content, message_read_src.text)) is null then null else length(public._behavior_clean_text(coalesce(message_read_src.content, message_read_src.text))) end,
    'message_preview', case when public._behavior_clean_text(coalesce(message_read_src.content, message_read_src.text)) is null then null else left(public._behavior_clean_text(coalesce(message_read_src.content, message_read_src.text)), 120) end,
    'has_image', message_read_src.image_url is not null,
    'read_delay_seconds', case
      when message_read_src.read_at is null or message_read_src.created_at is null then null
      else greatest(0, floor(extract(epoch from (message_read_src.read_at - message_read_src.created_at))))::int
    end
  )) as metadata,
  message_read_src.mapped_correlation_id as correlation_id,
  (select be.id from public.behavior_events be where be.source_event_key = format('messages:%s:sent', message_read_src.id) limit 1) as causation_id,
  'both' as visibility_scope,
  1 as schema_version,
  now() as created_at
from message_read_src
where coalesce(message_read_src.client_id, message_read_src.sender_id, message_read_src.receiver_id) is not null
  and (
    message_read_src.mapped_reader_actor_type in ('system', 'ai')
    or message_read_src.receiver_id is not null
  )
on conflict (source_event_key) do nothing;

insert into public.behavior_events (
  occurred_at,
  primary_user_id,
  actor_type,
  actor_id,
  event_family,
  event_type,
  origin_kind,
  source_table,
  source_id,
  source_event_key,
  summary,
  metadata,
  correlation_id,
  causation_id,
  visibility_scope,
  schema_version,
  created_at
)
select
  coalesce(ci.created_at, ci.updated_at, now()) as occurred_at,
  ci.user_id as primary_user_id,
  public._behavior_actor_type('client') as actor_type,
  ci.user_id as actor_id,
  'checkin' as event_family,
  'checkin_submitted' as event_type,
  'raw' as origin_kind,
  'check_ins' as source_table,
  ci.id as source_id,
  format('check_ins:%s:submitted', ci.id) as source_event_key,
  public._behavior_checkin_summary('daily', ci.mood, coalesce(ci.stress, ci.stress_level), coalesce(ci.energy, ci.energy_level)) as summary,
  jsonb_strip_nulls(jsonb_build_object(
    'checkin_id', ci.id,
    'checkin_date', ci.date,
    'checkin_kind', 'daily',
    'mood', ci.mood,
    'stress', coalesce(ci.stress, ci.stress_level),
    'energy', coalesce(ci.energy, ci.energy_level)
  )) as metadata,
  null as correlation_id,
  null as causation_id,
  'both' as visibility_scope,
  1 as schema_version,
  now() as created_at
from public.check_ins ci
where ci.user_id is not null
on conflict (source_event_key) do nothing;

-- Backfill for already existing auth users.
insert into public.users (id, email, role)
select id, email, 'client'
from auth.users
on conflict (id) do nothing;

create table if not exists public.coach_workqueue_items (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  priority_score numeric(6,2) not null default 0,
  priority_level text not null default 'low',
  queue_state text not null default 'resolved',
  attention_reason text not null default 'No active attention reason.',
  recommended_action text not null default 'no_action',
  behavior_snapshot jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  source_event_id uuid references public.behavior_events(id) on delete set null,
  source_event_type text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  resolved_at timestamp with time zone,
  last_evaluated_at timestamp with time zone not null default now()
);

alter table public.coach_workqueue_items
  add column if not exists coach_id uuid references public.users(id) on delete cascade,
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists priority_score numeric(6,2) not null default 0,
  add column if not exists priority_level text not null default 'low',
  add column if not exists queue_state text not null default 'resolved',
  add column if not exists attention_reason text not null default 'No active attention reason.',
  add column if not exists recommended_action text not null default 'no_action',
  add column if not exists behavior_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists source_event_id uuid references public.behavior_events(id) on delete set null,
  add column if not exists source_event_type text,
  add column if not exists created_at timestamp with time zone not null default now(),
  add column if not exists updated_at timestamp with time zone not null default now(),
  add column if not exists resolved_at timestamp with time zone,
  add column if not exists last_evaluated_at timestamp with time zone not null default now();

alter table public.coach_workqueue_items
  alter column priority_score set default 0,
  alter column priority_level set default 'low',
  alter column queue_state set default 'resolved',
  alter column attention_reason set default 'No active attention reason.',
  alter column recommended_action set default 'no_action',
  alter column behavior_snapshot set default '{}'::jsonb,
  alter column metadata set default '{}'::jsonb,
  alter column created_at set default now(),
  alter column updated_at set default now(),
  alter column last_evaluated_at set default now();

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_priority_level_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_priority_level_check
  check (priority_level in ('low', 'medium', 'high', 'urgent'));

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_queue_state_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_queue_state_check
  check (queue_state in ('active', 'snoozed', 'resolved', 'dismissed'));

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_recommended_action_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_recommended_action_check
  check (
    recommended_action in (
      'soft_checkin',
      'micro_step',
      'emotional_support',
      'recovery_prompt',
      'review_plan',
      'celebrate_progress',
      'clarify_barrier',
      'coach_followup',
      'no_action'
    )
  );

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_priority_score_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_priority_score_check
  check (priority_score >= 0 and priority_score <= 100);

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_attention_reason_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_attention_reason_check
  check (attention_reason is not null and btrim(attention_reason) <> '');

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_behavior_snapshot_object_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_behavior_snapshot_object_check
  check (behavior_snapshot is not null and jsonb_typeof(behavior_snapshot) = 'object');

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_metadata_object_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_metadata_object_check
  check (metadata is not null and jsonb_typeof(metadata) = 'object');

alter table public.coach_workqueue_items
  drop constraint if exists coach_workqueue_items_source_event_type_check;

alter table public.coach_workqueue_items
  add constraint coach_workqueue_items_source_event_type_check
  check (source_event_type is null or btrim(source_event_type) <> '');

create unique index if not exists idx_coach_workqueue_items_unique_coach_user
  on public.coach_workqueue_items(coach_id, user_id);
create index if not exists idx_coach_workqueue_items_coach_state_priority
  on public.coach_workqueue_items(coach_id, queue_state, priority_level, priority_score desc, updated_at desc);
create index if not exists idx_coach_workqueue_items_user_state
  on public.coach_workqueue_items(user_id, queue_state, updated_at desc);
create index if not exists idx_coach_workqueue_items_last_evaluated_at
  on public.coach_workqueue_items(last_evaluated_at desc);

alter table public.coach_workqueue_items
  enable row level security;

drop policy if exists "coach_workqueue_items_select_coach_own_clients" on public.coach_workqueue_items;

create policy "coach_workqueue_items_select_coach_own_clients"
on public.coach_workqueue_items
for select
to authenticated
using (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_workqueue_items_insert_coach_own_clients" on public.coach_workqueue_items;

create policy "coach_workqueue_items_insert_coach_own_clients"
on public.coach_workqueue_items
for insert
to authenticated
with check (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_workqueue_items_update_coach_own_clients" on public.coach_workqueue_items;

create policy "coach_workqueue_items_update_coach_own_clients"
on public.coach_workqueue_items
for update
to authenticated
using (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
)
with check (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_workqueue_items_delete_none" on public.coach_workqueue_items;

create policy "coach_workqueue_items_delete_none"
on public.coach_workqueue_items
for delete
to authenticated
using (false);

drop trigger if exists coach_workqueue_items_touch_updated_at on public.coach_workqueue_items;

create trigger coach_workqueue_items_touch_updated_at
before update on public.coach_workqueue_items
for each row execute function public._behavior_touch_updated_at();

comment on table public.coach_workqueue_items is 'Derived operational attention queue for coaches. One row represents the current routing state for a coach-client pair.';
comment on column public.coach_workqueue_items.behavior_snapshot is 'Structured rule-based snapshot used for explainable attention routing.';
comment on column public.coach_workqueue_items.metadata is 'Operational evaluation metadata and score breakdown.';

create table if not exists public.coach_interventions (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  workqueue_item_id uuid references public.coach_workqueue_items(id) on delete set null,
  intervention_type text not null,
  intervention_channel text not null,
  status text not null default 'pending',
  message_id uuid references public.messages(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  trigger_event_id uuid references public.behavior_events(id) on delete set null,
  correlation_id uuid,
  causation_id uuid,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  delivered_at timestamp with time zone,
  acknowledged_at timestamp with time zone,
  responded_at timestamp with time zone,
  updated_at timestamp with time zone not null default now()
);

alter table public.coach_interventions
  add column if not exists coach_id uuid references public.users(id) on delete cascade,
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists workqueue_item_id uuid references public.coach_workqueue_items(id) on delete set null,
  add column if not exists intervention_type text,
  add column if not exists intervention_channel text,
  add column if not exists status text default 'pending',
  add column if not exists message_id uuid references public.messages(id) on delete set null,
  add column if not exists conversation_id uuid references public.conversations(id) on delete set null,
  add column if not exists trigger_event_id uuid references public.behavior_events(id) on delete set null,
  add column if not exists correlation_id uuid,
  add column if not exists causation_id uuid,
  add column if not exists summary text,
  add column if not exists metadata jsonb default '{}'::jsonb,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists delivered_at timestamp with time zone,
  add column if not exists acknowledged_at timestamp with time zone,
  add column if not exists responded_at timestamp with time zone,
  add column if not exists updated_at timestamp with time zone default now();

alter table public.coach_interventions
  alter column status set default 'pending',
  alter column metadata set default '{}'::jsonb,
  alter column created_at set default now(),
  alter column updated_at set default now();

alter table public.coach_interventions
  drop constraint if exists coach_interventions_intervention_type_check;

alter table public.coach_interventions
  add constraint coach_interventions_intervention_type_check
  check (
    intervention_type in (
      'soft_checkin',
      'recovery_prompt',
      'reflection_prompt',
      'emotional_support',
      'micro_step',
      'plan_adjustment',
      'celebration',
      'reminder',
      'escalation'
    )
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_intervention_channel_check;

alter table public.coach_interventions
  add constraint coach_interventions_intervention_channel_check
  check (
    intervention_channel in (
      'chat',
      'push',
      'in_app',
      'coach_manual',
      'ai_suggested'
    )
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_status_check;

alter table public.coach_interventions
  add constraint coach_interventions_status_check
  check (
    status in ('pending', 'delivered', 'acknowledged', 'responded', 'expired', 'cancelled')
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_summary_check;

alter table public.coach_interventions
  add constraint coach_interventions_summary_check
  check (btrim(summary) <> '');

alter table public.coach_interventions
  drop constraint if exists coach_interventions_metadata_object_check;

alter table public.coach_interventions
  add constraint coach_interventions_metadata_object_check
  check (metadata is not null and jsonb_typeof(metadata) = 'object');

alter table public.coach_interventions
  drop constraint if exists coach_interventions_correlation_id_check;

alter table public.coach_interventions
  add constraint coach_interventions_correlation_id_check
  check (
    (status in ('acknowledged', 'responded') and correlation_id is not null)
    or status in ('pending', 'delivered', 'expired', 'cancelled')
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_delivered_at_check;

alter table public.coach_interventions
  add constraint coach_interventions_delivered_at_check
  check (
    (status in ('delivered', 'acknowledged', 'responded') and delivered_at is not null)
    or status in ('pending', 'expired', 'cancelled')
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_responded_at_check;

alter table public.coach_interventions
  add constraint coach_interventions_responded_at_check
  check (
    (status = 'responded' and responded_at is not null)
    or status in ('pending', 'delivered', 'acknowledged', 'expired', 'cancelled')
  );

alter table public.coach_interventions
  drop constraint if exists coach_interventions_summary_nonempty_check;

alter table public.coach_interventions
  add constraint coach_interventions_summary_nonempty_check
  check (summary is not null and btrim(summary) <> '');

create index if not exists idx_coach_interventions_coach_user_created_at
  on public.coach_interventions(coach_id, user_id, created_at desc);
create index if not exists idx_coach_interventions_workqueue_item_id
  on public.coach_interventions(workqueue_item_id);
create index if not exists idx_coach_interventions_status_created_at
  on public.coach_interventions(status, created_at desc);
create index if not exists idx_coach_interventions_trigger_event_id
  on public.coach_interventions(trigger_event_id);
create index if not exists idx_coach_interventions_conversation_id
  on public.coach_interventions(conversation_id);
create index if not exists idx_coach_interventions_correlation_id
  on public.coach_interventions(correlation_id);
create index if not exists idx_coach_interventions_causation_id
  on public.coach_interventions(causation_id);

alter table public.coach_interventions
  enable row level security;

drop policy if exists "coach_interventions_select_coach_own_clients" on public.coach_interventions;

create policy "coach_interventions_select_coach_own_clients"
on public.coach_interventions
for select
to authenticated
using (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_interventions_insert_coach_own_clients" on public.coach_interventions;

create policy "coach_interventions_insert_coach_own_clients"
on public.coach_interventions
for insert
to authenticated
with check (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_interventions_update_coach_own_clients" on public.coach_interventions;

create policy "coach_interventions_update_coach_own_clients"
on public.coach_interventions
for update
to authenticated
using (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
)
with check (
  coach_id = auth.uid()
  and public._behavior_is_coach_for_user(user_id)
);

drop policy if exists "coach_interventions_delete_none" on public.coach_interventions;

create policy "coach_interventions_delete_none"
on public.coach_interventions
for delete
to authenticated
using (false);

drop trigger if exists coach_interventions_touch_updated_at on public.coach_interventions;

create trigger coach_interventions_touch_updated_at
before update on public.coach_interventions
for each row execute function public._behavior_touch_updated_at();

comment on table public.coach_interventions is 'Append-only intervention log for coach, system, and AI-routed support actions.';
comment on column public.coach_interventions.metadata is 'Structured operational metadata, including provenance and response timing.';

create or replace function public._behavior_ingest_coach_intervention_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_primary_user_id uuid := new.user_id;
  v_actor_type text := public._behavior_actor_type(coalesce((select u.role from public.users u where u.id = new.coach_id limit 1), 'coach'));
  v_correlation_id uuid := coalesce(new.correlation_id, public._behavior_jsonb_uuid(new.metadata, 'correlation_id'));
  v_causation_id uuid := coalesce(new.causation_id, new.trigger_event_id);
  v_event_type text;
  v_summary text;
  v_metadata jsonb;
  v_event_id uuid;
  v_event_key text;
  v_source_event_type text;
begin
  if tg_op = 'INSERT' then
    v_event_type := 'intervention_created';
    v_summary := coalesce(public._behavior_clean_text(new.summary), 'Coach intervention created');
    v_source_event_type := 'created';
    v_event_key := format('coach_interventions:%s:created', new.id);
    v_metadata := jsonb_strip_nulls(jsonb_build_object(
      'coach_intervention_id', new.id,
      'workqueue_item_id', new.workqueue_item_id,
      'intervention_type', new.intervention_type,
      'intervention_channel', new.intervention_channel,
      'status', new.status,
      'message_id', new.message_id,
      'conversation_id', new.conversation_id,
      'trigger_event_id', new.trigger_event_id,
      'summary', new.summary
    ));

    perform public._behavior_store_event(
      p_primary_user_id := v_primary_user_id,
      p_actor_type := v_actor_type,
      p_actor_id := new.coach_id,
      p_event_family := 'intervention',
      p_event_type := v_event_type,
      p_origin_kind := 'raw',
      p_source_table := 'coach_interventions',
      p_source_id := new.id,
      p_source_event_key := v_event_key,
      p_summary := v_summary,
      p_metadata := v_metadata,
      p_correlation_id := v_correlation_id,
      p_causation_id := v_causation_id,
      p_visibility_scope := 'coach',
      p_occurred_at := coalesce(new.created_at, now())
    );

    return new;
  end if;

  if old.status is distinct from new.status then
    if new.status = 'delivered' then
      return new;
    elsif new.status = 'responded' then
      v_event_type := 'intervention_responded';
      v_source_event_type := 'responded';
      v_summary := coalesce(public._behavior_clean_text(new.summary), 'Client responded to intervention');
      v_event_key := format('coach_interventions:%s:responded', new.id);
      v_metadata := jsonb_strip_nulls(jsonb_build_object(
        'coach_intervention_id', new.id,
        'status', new.status,
        'responded_at', new.responded_at,
        'summary', new.summary
      ));
      perform public._behavior_store_event(
        p_primary_user_id := v_primary_user_id,
        p_actor_type := public._behavior_actor_type('client'),
        p_actor_id := new.user_id,
        p_event_family := 'intervention',
        p_event_type := v_event_type,
        p_origin_kind := 'raw',
        p_source_table := 'coach_interventions',
        p_source_id := new.id,
        p_source_event_key := v_event_key,
        p_summary := v_summary,
        p_metadata := v_metadata,
        p_correlation_id := v_correlation_id,
        p_causation_id := v_causation_id,
        p_visibility_scope := 'coach',
        p_occurred_at := coalesce(new.responded_at, new.updated_at, now())
      );
    elsif new.status = 'expired' then
      v_event_type := 'intervention_expired';
      v_source_event_type := 'expired';
      v_summary := coalesce(public._behavior_clean_text(new.summary), 'Coach intervention expired');
      v_event_key := format('coach_interventions:%s:expired', new.id);
      v_metadata := jsonb_strip_nulls(jsonb_build_object(
        'coach_intervention_id', new.id,
        'status', new.status,
        'summary', new.summary
      ));
      perform public._behavior_store_event(
        p_primary_user_id := v_primary_user_id,
        p_actor_type := v_actor_type,
        p_actor_id := new.coach_id,
        p_event_family := 'intervention',
        p_event_type := v_event_type,
        p_origin_kind := 'raw',
        p_source_table := 'coach_interventions',
        p_source_id := new.id,
        p_source_event_key := v_event_key,
        p_summary := v_summary,
        p_metadata := v_metadata,
        p_correlation_id := v_correlation_id,
        p_causation_id := v_causation_id,
        p_visibility_scope := 'coach',
        p_occurred_at := coalesce(new.updated_at, now())
      );
    elsif new.status = 'cancelled' then
      v_event_type := 'intervention_expired';
      v_source_event_type := 'cancelled';
      v_summary := coalesce(public._behavior_clean_text(new.summary), 'Coach intervention cancelled');
      v_event_key := format('coach_interventions:%s:cancelled', new.id);
      v_metadata := jsonb_strip_nulls(jsonb_build_object(
        'coach_intervention_id', new.id,
        'status', new.status,
        'summary', new.summary
      ));
      perform public._behavior_store_event(
        p_primary_user_id := v_primary_user_id,
        p_actor_type := v_actor_type,
        p_actor_id := new.coach_id,
        p_event_family := 'intervention',
        p_event_type := v_event_type,
        p_origin_kind := 'raw',
        p_source_table := 'coach_interventions',
        p_source_id := new.id,
        p_source_event_key := v_event_key,
        p_summary := v_summary,
        p_metadata := v_metadata,
        p_correlation_id := v_correlation_id,
        p_causation_id := v_causation_id,
        p_visibility_scope := 'coach',
        p_occurred_at := coalesce(new.updated_at, now())
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists coach_interventions_ingest_behavior_event on public.coach_interventions;

create trigger coach_interventions_ingest_behavior_event
after insert or update of status on public.coach_interventions
for each row execute function public._behavior_ingest_coach_intervention_event();

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
