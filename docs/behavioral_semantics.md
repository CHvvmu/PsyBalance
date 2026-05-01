# Behavioral Semantics

This document defines the canonical meaning of behavior in PsyBalance.
The system should stay operational, explainable, and non-diagnostic.

## Canonical event taxonomy

### Task events

- `task_completed` — a task was completed
- `task_skipped` — a task was explicitly skipped
- `task_reopened` — a task became active again after previously being closed/finished
- `task_auto_closed` — a task was closed by rule, not by a human completion signal

### Message events

- `message_sent` — a message was authored and stored
- `message_read` — the receiver read the message

### Check-in events

- `checkin_submitted` — a client check-in was recorded
- `emotional_checkin_submitted` — a check-in variant with emotional signal

### Intervention events

- `intervention_created` — a coach intervention row was inserted
- `intervention_responded` — the client responded to an intervention
- `intervention_expired` — the response window passed without the expected response

### Other operational events

- `reflection_prompt_sent`
- `reengagement_prompt_sent`
- `coach_recommended_task`
- `risk_flagged`
- `streak_changed`

## Task semantics

Task activity is intentionally richer than the cached task status.

```text
task_activity event -> behavior_events fact -> plan_items.status projection
```

- `completed` means the task was completed and may project to `done`
- `skipped` means the task was explicitly not done; it stays visible in the event log
- `reopened` means the work is active again and may project back to `in_progress`
- `auto_closed` means a rule closed the task, not a human completion

Important: the task projection is intentionally coarse. It does not need to preserve
every semantic distinction in the source event. The event log keeps the detail.

## Reminder semantics

Reminders and follow-ups are support signals, not pressure instruments.

- `checkin_followup` should feel like a gentle nudge
- `reflection_prompt` should invite thinking, not compliance
- `intervention` should remain coach-authored and explainable

## Silence semantics

Silence is a gap in observable behavior, not a diagnosis.

Derived silence signals include:

- `silence_days`
- `read_no_reply`
- `recent_intervention_no_response`
- `missed_checkin`
- `return_after_silence`

Silence should be interpreted operationally:

- is the client absent?
- is there read activity without response?
- has the client returned after a pause?
- did an intervention fail to produce a response in its window?

## Engagement semantics

Engagement is a composite of visible activity, not a hidden psychological score.

Helpful indicators in the current system:

- recent completed tasks
- recent check-ins
- messages sent or read
- consistency streak
- days since last meaningful activity

The current code uses these signals to build explainable snapshots and queue priorities.

## Recovery and relapse interpretation

The product uses operational language, not clinical language.

- `return_after_silence` means activity resumed after a meaningful gap
- `positive_momentum` means recent behavior is trending in a stable direction
- `instability` means recent task behavior and silence patterns look uneven
- `repeated_avoidance` means multiple interventions or read states did not produce a response

These labels describe observable patterns. They do not describe mental state.

## Metadata strategy

Metadata should carry explanation, not hidden scoring.

Current intervention metadata intentionally records fields such as:

- `behavioral_intent`
- `coaching_phase`
- `risk_context`
- `expected_response_window_hours`
- `tone`
- `followup_strategy`
- `pressure_level`

The metadata object should stay JSON-object shaped and human-readable.

## Anti-patterns

- do not infer diagnosis
- do not infer hidden motivation as fact
- do not create opaque scores without explanation
- do not pressure a client to reply
- do not optimize for addiction-like engagement
- do not auto-send emotional interventions

## Raw events vs derived signals

Raw events are source facts.
Derived signals are interpretations built from those facts.

Examples:

- raw: a message was read
- derived: the system labels the pattern as `read_no_reply`

- raw: a task was completed
- derived: the snapshot labels the period as `positive_momentum`

- raw: an intervention was delivered
- derived: the outcome may later be `meaningful_reply` or `repeated_avoidance`

This distinction matters because the app must stay explainable and debuggable.

