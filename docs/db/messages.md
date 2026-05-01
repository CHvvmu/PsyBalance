# `messages`

`messages` stores durable 1:1 chat rows.

## Meaning

It is both a communication table and a source table for the behavior timeline.

## Important columns

- `conversation_id`
- `sender_id`
- `receiver_id`
- `sender_role`
- `message_type`
- `content` / `text`
- `read_at`
- `metadata`

## Implementation notes

- chat writes use `send_chat_message(...)`
- reads use `mark_conversation_messages_read(...)`
- message inserts ingest `message_sent`
- read updates ingest `message_read`
- realtime subscriptions listen to Postgres changes on this table

