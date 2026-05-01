# `conversations`

`conversations` stores the direct client/coach pairing for chat.

## Meaning

It is a cached relationship row for the 1:1 thread.

## Why it exists

The system needs a stable place to anchor message history, last-message caches,
and realtime subscriptions.

## Implementation notes

- `get_or_create_direct_conversation(p_peer_user_id)` uses this table
- `messages` update the last-message cache fields
- the table is row-level secure for participants

