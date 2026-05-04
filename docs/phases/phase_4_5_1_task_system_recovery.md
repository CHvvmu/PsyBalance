# Phase 4.5.1 — Task System Recovery

## Stabilization artifact

This phase records the recovery of the task system after live schema drift.

## Root cause

- live schema mismatch
- missing runtime functions
- projection semantics mismatch

## Critical runtime blockers restored

- active plan loading
- `task_activity` chain
- `append_task_event` chain
- projection rebuild chain
- `_behavior_task_owner_id`
- canonical task status projection

## Mandatory invariants

- `task_*` events must map canonically in the projection layer
- `plan_items.status` is projection-only state
- `task_activity` is an append-only behavioral source
- client and coach must observe the same committed projection state

## SQL patches that must stay in the main migration flow

- live schema alignment for `task_activity` and task ownership lookup
- `_behavior_append_task_event`
- `_behavior_task_owner_id`
- `rebuild_task_projection`
- canonical task status normalization in the projection layer
- any companion migration statements needed to keep `plan_items` synced from `task_activity`

## Confirmed operational flows

- coach creates task
- client sees task
- complete / skip / reopen work
- status persists after reload
- coach/client stay synchronized

