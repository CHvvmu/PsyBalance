# Phase 1 — Task Event Migration

## What this phase did

This phase converted task handling from a simple status-centric model into a
behavior-event model.

Key schema pieces:

- `task_activity` stores the raw task action rows
- `record_task_event(...)` is the controlled write path
- `rebuild_task_projection(...)` updates `plan_items.status`
- `behavior_events` ingests task activity as canonical events

## Why it exists

The product needs task history that can answer more than "done or not done".
It needs to know whether the task was completed, skipped, reopened, or auto-closed.

## Production-safe implementation

- task writes are normalized in SQL
- the projection is rebuilt from source activity
- the event log remains append-only
- the cached `plan_items.status` is kept intentionally coarse

## Tradeoff

This adds one more layer between source action and UI status, but that is the point:
the timeline and AI layers get richer evidence while the UI remains simple.

