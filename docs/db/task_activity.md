# `task_activity`

`task_activity` is the raw task action table.

## Meaning

It records task events such as completion, skip, and reopen.
It is the source table, not the projection.

## Important columns

- `task_id`
- `event_type`
- `event_source`
- `completed`
- `skipped`
- `completed_at`
- `metadata`

## Semantics

- `completed` becomes the source fact for `task_completed`
- `skipped` becomes the source fact for `task_skipped`
- `reopened` marks the task active again

## Implementation notes

- write normalization happens in `_behavior_normalize_task_activity_event()`
- ingest happens in `_behavior_ingest_task_activity_event()`
- projection rebuild happens via `rebuild_task_projection(task_id)`

