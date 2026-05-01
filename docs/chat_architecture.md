# Chat Architecture

The chat system is a direct, real-time, coach-client conversation channel.
It is built to be durable and explainable, not illusionary.

## Why this architecture exists

The coach and client need a stable 1:1 thread with message history, read state,
and realtime updates. The chat layer must also feed the behavioral timeline so
silence, response, and re-engagement can be interpreted later.

## Conversation model

`conversations` stores a direct pair:

- `client_id`
- `coach_id`

The RPC `get_or_create_direct_conversation(p_peer_user_id)` creates or returns the
correct pairwise conversation for the current authenticated user.

This is intentionally not a group-chat model.

## Message model

`messages` stores the durable chat rows with:

- `conversation_id`
- `sender_id`
- `receiver_id`
- `sender_role`
- `message_type`
- `content` / `text`
- `metadata`
- `read_at`

The schema keeps `content` and `text` together for compatibility.
The write path normalizes them so the message body is not ambiguous.

## Current realtime architecture

The chat page subscribes to Postgres changes on `public.messages` for the active
conversation:

```text
messages table insert/update
        -> Supabase Realtime postgres_changes
        -> chat page refresh
        -> reload messages from DB
```

Why this choice:

- it follows committed database state, not optimistic UI fiction
- it is simple to filter by `conversation_id`
- it works with the schema's append/read-state model

## Read-state semantics

Read state is not a UI flag.
It is an actual database update:

- the client or coach calls `mark_conversation_messages_read(p_conversation_id)`
- the `read_at` column changes on the relevant rows
- a trigger ingests a `message_read` behavior event

This makes read state visible to the timeline and later outcome analysis.

## Why there are no optimistic fake bubbles

The UI does not pretend a message exists before the database write succeeds.
It waits for the RPC result and then reloads from the server.

That tradeoff keeps the interface honest:

- fewer mismatches between local state and committed rows
- fewer edge cases when the RPC fails
- better alignment with the event-first architecture

## Behavioral messaging semantics

Message metadata carries operational context such as:

- source screen
- trigger
- conversation id
- peer user id
- behavior user id

The workqueue and chat send paths both write messages through `send_chat_message(...)`.
That keeps messaging behavior consistent whether it is initiated from the coach panel
or from the chat screen itself.

## Silence detection preparation

Silence analysis depends on committed message and read events:

- a sent message without a reply can become `read_no_reply`
- repeated sends without response can become `recent_intervention_no_response`
- a later client response can become `return_after_silence`

Because the chat layer feeds `behavior_events`, the system can later reason about
response windows without scraping the UI.

## Current limitations

- direct 1:1 chat only
- no group chat
- no optimistic local message authoring state
- no AI-generated automatic emotional intervention

Those are deliberate MVP choices, not missing pieces.

