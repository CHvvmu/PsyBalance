# Phase 3 — Behavior Timeline

## What this phase did

This phase created the canonical behavioral feed and the explainable snapshot layer.

Key pieces:

- `behavior_events`
- ingest triggers for tasks, messages, reads, check-ins, and interventions
- `build_behavior_snapshot(uuid)`
- `evaluate_coach_workqueue()`

## Why it exists

The product needs one unified event stream that can explain what happened over time.

## Production-safe implementation

- source rows are normalized into a shared event vocabulary
- behavior events are append-only
- snapshots are derived, not hand-edited
- the coach workqueue is a cached projection over that feed

## Tradeoff

The project now has both source tables and derived projections.
That is slightly more complex, but it keeps the system explainable and reusable.

