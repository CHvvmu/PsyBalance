# Completed Phases

This is the historical record of the implementation phases already completed in the repo.

## Phase 1 — Task event migration

### What changed

- `task_activity` became the source event log for task actions
- write normalization was added for `completed`, `skipped`, and `reopened`
- `record_task_event(...)` writes task events safely
- `rebuild_task_projection(...)` refreshes cached `plan_items.status`
- task activity is ingested into `behavior_events`

### Why it matters

This moved task history from a simple status column to a behavior-aware event flow.
It is the basis for later silence, recovery, and completion interpretation.

## Phase 2 — Realtime chat

### What changed

- direct conversation RPC: `get_or_create_direct_conversation(...)`
- message send RPC: `send_chat_message(...)`
- read-state RPC: `mark_conversation_messages_read(...)`
- realtime updates on `messages` via Supabase Postgres changes
- route support for initial drafts in coach chat

### Why it matters

This gave the app a real-time chat channel without inventing local-only message state.

## Phase 3 — Behavior timeline

### What changed

- `behavior_events` became the canonical normalized event read model
- source ingestion was added for tasks, messages, reads, check-ins, and interventions
- `build_behavior_snapshot(uuid)` now builds explainable attention state
- `evaluate_coach_workqueue()` upserts the coach attention queue
- client-facing timeline surfaces were built from concrete behavior data

### Why it matters

This made cross-domain behavior observable in one sequence.

## Phase 4 — Intervention system

### What changed

- coach workqueue UI was implemented
- chat routing from the coach panel was wired
- coach interventions are logged in `coach_interventions`
- explainable intervention metadata was added through the semantics layer
- attribution now carries correlation and causation ids
- intervention outcome interpretation was added as a separate layer

### Why it matters

This is the first phase where the system can describe why a coach action happened
and what the response to it was, without pretending to be autonomous.

