# Database Architecture

PsyBalance uses an event-first schema with append-only logs and a small number of
cached projections for speed and UI convenience.

## Why this architecture exists

The product needs traceability more than transactional cleverness.
When a coach sees a recommendation, the system should be able to show the evidence
that produced it.

## Source of truth map

| Table / function | Role |
| --- | --- |
| `task_activity` | source event log for task changes |
| `messages` | source event log for chat messages and read-state |
| `conversations` | cached direct conversation relationship row |
| `behavior_events` | canonical append-only behavioral read model |
| `plan_items` | cached task projection |
| `coach_workqueue_items` | cached coaching projection |
| `coach_interventions` | append-only intervention log |
| `build_behavior_snapshot(uuid)` | explainable rule-based snapshot |
| `evaluate_coach_workqueue()` | projection refresh for coach attention routing |

## Why `behavior_events` is the read model

`behavior_events` is the canonical timeline because it normalizes multiple source tables
into a shared event vocabulary.

Benefits:

- one place to read behavior from
- one taxonomy for tasks, messages, check-ins, and interventions
- one place to attach correlation and causation IDs
- one place to reason about timeline and AI consumers

The source tables still matter because they preserve the raw, domain-specific facts.

## Why `plan_items.status` is a cached projection

`plan_items.status` is not the source of truth for task history.
It is a convenience view over the latest task activity.

The current projection keeps the UI simple:

- `pending`
- `in_progress`
- `done`

The source event log keeps the richer distinctions:

- completed
- skipped
- reopened
- auto-closed

That split is intentional. The UI gets speed and clarity; the event log keeps history.

## Trigger strategy

The schema uses triggers for three main jobs:

1. normalize source rows on write
2. ingest source rows into `behavior_events`
3. keep cached projections in sync

Examples from the current schema:

- `task_activity` normalizes write-side task semantics and then ingests an event
- `messages` normalizes write-side chat semantics and ingests send/read events
- `behavior_events` is append-only and rejects update/delete
- `conversations` keeps last-message cache fields updated from message inserts

## RLS philosophy

Row-level security is scoped to the operational relationship:

- clients see their own data
- coaches see their own clients
- participants can write only where they are allowed to act

The application should never rely on client-side filtering for data safety.

## Realtime strategy

The current realtime approach is pragmatic:

- use Supabase Postgres changes for committed database events
- subscribe to the table that already reflects durable state
- refresh the screen from the database after the change

Known realtime publication points in the schema include:

- `public.conversations`
- `public.messages`
- `public.behavior_events`

## Idempotency strategy

The schema uses `source_event_key` and `on conflict do nothing` patterns so that
ingestion can be retried safely.

This matters because:

- triggers may fire from the same source row more than once in operational scenarios
- backfills may rerun
- projection jobs may be scheduled periodically

The design prefers safe duplicate suppression over complicated distributed coordination.

