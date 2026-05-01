# Current Roadmap

This roadmap reflects the real implementation state of PsyBalance.
It should be read as a maintenance map, not as a marketing plan.

## Completed implementation phases

- Phase 1: task event migration
- Phase 2: realtime chat
- Phase 3: behavior timeline
- Phase 4: intervention system

Those phases are documented in [completed_phases.md](./completed_phases.md).

## Active workstream

The current active workstream is the documentation foundation / master context system.

The product implementation is already strong enough to document, but the project
needs durable memory so future changes do not drift away from the actual design.

## Next likely implementation work

These are the most plausible future steps based on the current architecture:

1. broader AI-read-only consumers over the timeline and snapshots
2. richer intervention review surfaces for coaches
3. more presentation layers over the normalized behavior feed
4. gradual expansion of intervention types where the coach UX can support them

These are not commitments to autonomous AI behavior.

## Known bottlenecks

### 1. Projection evaluation cost

`evaluate_coach_workqueue()` iterates coach-client pairs and upserts projections.
That is acceptable for the MVP but will eventually need attention if the cohort grows.

### 2. Multiple timeline surfaces

Today there is both:

- a canonical behavioral feed in `behavior_events`
- presentation timelines assembled from source tables in the UI

That is fine for MVP, but the boundaries need to stay clear.

### 3. Realtime vs reload

Chat currently uses realtime change notifications plus explicit reloads.
This is simple and reliable, but it is not the minimal network path.

### 4. Manual metadata construction

The app is now using a shared semantics helper, but future features may still need
consistent metadata wiring discipline.

## Technical debt intentionally postponed

- no Bloc/Riverpod overhaul
- no autonomous AI sending
- no hidden engagement scoring
- no analytics warehouse migration
- no group chat redesign
- no enterprise event bus

That postponement is intentional and protects the MVP.

## Roadmap rule

If a future change reduces explainability, it needs a stronger justification than
feature growth alone.

