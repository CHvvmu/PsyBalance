# Phase 4 — Intervention System

## What this phase did

This phase added the coach intervention layer on top of the behavioral timeline.

Key pieces:

- `coach_workqueue_items`
- `coach_interventions`
- `coach_intervention_semantics.dart`
- workqueue UI actions
- intervention attribution and outcome interpretation

## Why it exists

The system needed a stable way to turn explainable signals into an explainable
coach action, then trace what happened afterward.

## Production-safe implementation

- coach chooses the intervention
- metadata records behavioral intent, tone, pressure, and response window
- the sent message and intervention row are written explicitly
- `correlation_id` and `causation_id` preserve the chain

## Tradeoff

The intervention system is intentionally manual and conservative.
That limits automation, but it protects dignity and keeps the coach in control.

