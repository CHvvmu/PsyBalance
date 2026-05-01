# Intervention System

The intervention system is the coach-facing layer for turning behavioral signals
into a concrete support action with an explainable reason.

## Why this system exists

The product needs to help a coach move from:

```text
signals -> interpretation -> coach decision -> delivered intervention -> observed outcome
```

without hiding any step behind an opaque score or autonomous AI.

## Current shipping shape

The current coach workqueue page supports a manual intervention flow with:

- soft check-in
- micro-step
- open chat
- review timeline
- snooze
- resolve

The workqueue sends a chat message via `send_chat_message(...)` and records a row
in `coach_interventions`.

## Data contract

`coach_interventions` is the append-only intervention log.
It stores:

- coach and user ids
- workqueue item id
- intervention type and channel
- status
- message/conversation ids
- trigger event id
- correlation id
- causation id
- summary
- metadata

The schema already enforces validity and response-time fields.

## Explainable metadata

The semantics layer in `lib/features/coach_panel/domain/coach_intervention_semantics.dart`
adds a stable metadata contract with fields such as:

- `behavioral_intent`
- `coaching_phase`
- `risk_context`
- `expected_response_window_hours`
- `tone`
- `followup_strategy`
- `pressure_level`

This metadata exists to explain why the intervention was chosen.
It is not a hidden AI score.

## Attribution

The intervention chain uses two important ids:

- `correlation_id` — stable chain id for the workqueue item / intervention thread
- `causation_id` — source event that triggered the intervention when known

That gives the system a traceable line from source behavior to coach action.

Example chain:

```text
behavior_events source -> coach_workqueue_items row -> coach intervention -> chat message -> later response event
```

## Outcome interpretation

The outcome layer derives labels from signals across:

- `behavior_events`
- `task_activity`
- `messages`

Canonical outcome labels used by the semantics layer:

- No response
- Acknowledged only
- Meaningful reply
- Task completion after intervention
- Return after silence
- Repeated avoidance

Those labels are operational descriptions, not mental-state claims.

## Important boundary

The system does **not**:

- auto-send emotional interventions
- make diagnoses
- pressure a client to reply
- optimize for addictive engagement
- run autonomous therapy

The coach remains the decision-maker.

## Current extension direction

The schema supports a richer intervention taxonomy than the current UI exposes.
That is useful for future controlled expansion, but the shipping behavior should
stay conservative until the semantics are proven in production.

