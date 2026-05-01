# Phase 2 — Realtime Chat

## What this phase did

This phase wired direct 1:1 chat with realtime updates and proper read-state.

Current building blocks:

- `conversations`
- `messages`
- `get_or_create_direct_conversation(...)`
- `send_chat_message(...)`
- `mark_conversation_messages_read(...)`
- Supabase realtime on `messages`

## Why it exists

The coach and client need a dependable async thread that reflects committed data.

## Production-safe implementation

- messages are written through RPC
- the screen listens to Postgres changes, then reloads from the database
- read state is stored in `read_at`
- chat rows feed `behavior_events`

## Tradeoff

The UI does not fake optimistic bubbles.
That is slower than a purely local chat illusion, but it is much safer and easier
to reason about.

