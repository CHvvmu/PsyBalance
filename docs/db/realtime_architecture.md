# Realtime Architecture

Realtime in PsyBalance is pragmatic and committed-state based.

## Current pattern

- write to Postgres through RPCs or controlled inserts
- let Supabase Realtime publish the committed change
- refresh the UI from the database after the event

## Tables already published in the schema

- `conversations`
- `messages`
- `behavior_events`

## Why not fake local state

The app prefers honest committed data over optimistic illusions.

