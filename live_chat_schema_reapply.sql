-- Canonical live chat schema reapply for a partially applied Supabase migration.
-- Safe to run multiple times.
-- This restores the bootstrap-critical chat table, RPC, indexes, grants, and RLS.

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

grant usage on schema public to authenticated;
grant select, insert on table public.conversations to authenticated;
grant select, insert, update, delete on table public.messages to authenticated;

grant execute on function public._behavior_is_conversation_participant(uuid) to authenticated;

grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text, text, jsonb, text) to authenticated;
grant execute on function public.mark_conversation_messages_read(uuid) to authenticated;

notify pgrst, 'reload schema';
