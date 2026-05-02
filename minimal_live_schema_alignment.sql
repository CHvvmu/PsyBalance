-- Minimal live schema alignment for active plan bootstrap.
-- Run this in the Supabase SQL editor on the live project.

create or replace function public._behavior_clean_text(p_text text)
returns text
language sql
immutable
as $$
  select nullif(btrim(regexp_replace(coalesce(p_text, ''), '[[:space:]]+', ' ', 'g')), '');
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
  created_at timestamp with time zone default now(),
  request_key text,
  source_event_key text,
  task_snapshot jsonb default '{}'::jsonb,
  archived_at timestamp with time zone
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
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists request_key text,
  add column if not exists source_event_key text,
  add column if not exists task_snapshot jsonb default '{}'::jsonb,
  add column if not exists archived_at timestamp with time zone;

alter table public.task_activity
  alter column event_source set default 'user',
  alter column metadata set default '{}'::jsonb,
  alter column updated_at set default now(),
  alter column created_at set default now();

update public.task_activity
set task_snapshot = coalesce(task_snapshot, '{}'::jsonb)
where task_snapshot is null;

create unique index if not exists idx_task_activity_request_key on public.task_activity(task_id, request_key) where request_key is not null;
create unique index if not exists idx_task_activity_source_event_key on public.task_activity(source_event_key) where source_event_key is not null;
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
      when coalesce(ta.completed, false) then 'task_completed'
      when coalesce(ta.skipped, false) then 'task_skipped'
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

  if v_latest_event_type in ('completed', 'task_completed') then
    return 'done';
  elsif v_latest_event_type in ('reopened', 'task_reopened') then
    return 'in_progress';
  else
    return 'pending';
  end if;
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

alter table public.plan_items
  add column if not exists description text,
  add column if not exists scheduled_at timestamp with time zone,
  add column if not exists task_category text,
  add column if not exists archived_at timestamp with time zone;

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

  perform pg_advisory_xact_lock(
    hashtext(format('get_or_create_active_plan:%s', p_user_id::text)),
    hashtext(v_week_start::text)
  );

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

notify pgrst, 'reload schema';
