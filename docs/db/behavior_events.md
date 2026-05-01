# `behavior_events`

`behavior_events` is the canonical append-only behavioral feed.

## Meaning

It stores normalized behavior facts across tasks, messages, check-ins, and
interventions.

## Contract

- append-only
- immutable history
- event family + event type taxonomy
- correlation and causation ids
- visibility scope for role-based reads

## Why it matters

This table is the main bridge between raw source tables and any future AI consumer.

