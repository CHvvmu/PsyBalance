# `messages`

`messages` stores durable 1:1 chat rows.

## Meaning

It is both a communication table and a source table for the behavior timeline.
For the current MVP, attachments are limited to images stored directly as
`image_url` on `public.messages`.

## Important columns

- `conversation_id`
- `sender_id`
- `receiver_id`
- `sender_role`
- `message_type`
- `content` / `text`
- `image_url`
- `read_at`
- `metadata`

## Implementation notes

- chat writes use `send_chat_message(...)`
- `send_chat_message(...)` accepts text-only, image-only, or text-plus-image payloads
- reads use `mark_conversation_messages_read(...)`
- message inserts ingest `message_sent`
- read updates ingest `message_read`
- realtime subscriptions listen to Postgres changes on this table
- the realtime/reload flow is unchanged for image messages
- the UI still waits for committed rows and does not create optimistic message bubbles

## Manual smoke checklist

- text-only send works
- image-only send works
- text-plus-image send works
- image messages still render after chat reload
- read state still changes on received messages
