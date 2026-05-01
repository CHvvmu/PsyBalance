# Projections

PsyBalance uses projections for current-state convenience, not for truth.

## Main projections

- `plan_items.status`
- `coach_workqueue_items`
- conversation last-message fields
- `build_behavior_snapshot(uuid)` output

## Why projections exist

They reduce UI complexity and keep the app responsive without rewriting the source
history every time a new rule is added.

## Rule

If a projection can be rebuilt from source facts, it should not be treated as the
source of truth.

