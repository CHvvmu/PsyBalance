# Current Architecture

PsyBalance is a Flutter client backed by Supabase Postgres, RPCs, row-level security,
and a small set of explainable projections.

## System shape

```text
Flutter UI
   -> Supabase RPCs / direct queries
   -> Postgres source tables
   -> append-only behavior_events timeline
   -> cached projections and snapshots
   -> coach UI, client UI, and AI-ready read layers
```

## Main layers

### Presentation

- Flutter screens and route wiring
- existing chat and coach-panel routing
- no wholesale state-management rewrite

### Data access

- Supabase client queries
- security-definer RPCs for write paths that need server-side rules
- direct read queries for projections and timelines

### Behavioral core

- `task_activity`
- `messages`
- `conversations`
- `behavior_events`
- `coach_workqueue_items`
- `coach_interventions`

### Derived views

- behavior snapshot (`build_behavior_snapshot(uuid)`)
- coach workqueue evaluation (`evaluate_coach_workqueue()`)
- timeline UI projection in client details
- intervention semantics and outcome interpretation

## Current boundary decisions

- the schema remains authoritative for data shape
- the app stays thin and uses the database as the main coordination point
- event history is preserved instead of overwritten
- projections are allowed to cache current state for speed and UI simplicity

## Why this architecture exists

The product needs to answer coach questions such as:

- what happened?
- what changed?
- what should be surfaced now?
- what is the evidence for that suggestion?

The architecture is optimized for those questions, not for generic app complexity.

