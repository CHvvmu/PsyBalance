# Timeline Architecture

The timeline is the system's unified behavioral feed.
It exists so the product can answer one question consistently across tasks,
messages, check-ins, and interventions:

> What happened, in what order, and what changed afterward?

## Why this layer exists

The product has multiple source tables, but coaches and future AI consumers need a
single chronological view. The timeline layer resolves that by normalizing events
into `behavior_events` and then deriving summaries and projections from that feed.

## Current architecture

```text
task_activity      messages        check-ins        coach_interventions
      \               |               |                   /
       \              |               |                  /
        -> normalization / ingest triggers / RPCs -> behavior_events
                                              |
                                              v
                               snapshots, workqueue, timeline UI, AI reads
```

## Ingestion pipeline

The schema currently ingests source facts into `behavior_events` through SQL
triggers and helper functions:

- `task_activity` -> `_behavior_ingest_task_activity_event()`
- `messages` -> `_behavior_ingest_message_event()`
- `messages.read_at` updates -> `_behavior_ingest_message_read_event()`
- check-in tables -> `_behavior_ingest_check_in_event()`
- `coach_interventions` -> `_behavior_ingest_coach_intervention_event()`

Each ingest path populates a shared event vocabulary and keeps source metadata.

## Source tables

The unified feed is not a replacement for the source tables.

- `task_activity` keeps the raw task action history
- `messages` keeps direct chat facts and read state
- check-in tables keep the client-reported state
- `coach_interventions` keeps the intervention log

The source tables remain the operational truth. `behavior_events` is the canonical
cross-domain read model.

## Normalization strategy

Normalization happens in two places:

1. source-row normalization on write
2. behavior-event normalization during ingest

Examples already in the schema:

- task events normalize into `task_completed`, `task_skipped`, `task_reopened`
- message writes normalize into `message_sent` or `message_read`
- intervention writes normalize into `intervention_created`, `intervention_responded`, or `intervention_expired`

This gives the system a stable event vocabulary without losing source detail.

## Summary generation

Behavior summaries are generated at ingest time through helper functions such as:

- `_behavior_task_summary(...)`
- `_behavior_message_summary(...)`
- `_behavior_checkin_summary(...)`

Those summaries are intentionally short and readable. They are not hidden scoring.

## Raw vs derived events

`behavior_events` stores raw ingested facts.
Derived signals are built on top of that feed by projections such as:

- `build_behavior_snapshot(uuid)`
- coach workqueue evaluation
- intervention outcome interpretation

This separation matters because derived labels can change while the raw history
must remain stable.

## Client-details timeline vs behavioral timeline

The coach client-details screen currently builds a presentation timeline from
source tables such as:

- recent check-ins
- completed plan items
- inbound messages
- outbound messages
- activity gaps

That UI timeline is useful, but it is not the same as the canonical behavioral feed.
The feed lives in `behavior_events` and is better suited for future AI consumers
because it already normalizes cross-domain semantics.

## Future AI consumption model

Future AI should consume the normalized feed first, then fall back to source tables
only when it needs richer detail.

Preferred order:

1. `behavior_events` for sequence and causation
2. `coach_interventions.metadata` for intervention context
3. `messages` and `task_activity` for raw details
4. source profile data only when a human coach needs it

That order keeps AI explainable and prevents overfitting to raw table structure.

