# PsyBalance Architecture Memory

This directory is the persistent architecture knowledge base for PsyBalance.
It is meant to survive code churn, not to market the product.

## Ground rule

If a document here disagrees with the code or SQL schema, the code and schema win.
The docs are explanatory memory; `ai_db_schema.sql` and the implementation are authoritative.

## What this tree contains

- product intent and MVP boundaries
- behavioral semantics and event vocabulary
- database and projection architecture
- realtime chat architecture
- intervention and workqueue semantics
- AI readiness constraints
- roadmap state and phase history
- UX philosophy for async coaching
- prompt templates for safe future changes

## Reading order

1. [product_vision.md](./product_vision.md)
2. [core_principles.md](./core_principles.md)
3. [current_architecture.md](./current_architecture.md)
4. [behavioral_semantics.md](./behavioral_semantics.md)
5. [db_architecture.md](./db_architecture.md)
6. [timeline_architecture.md](./timeline_architecture.md)
7. [chat_architecture.md](./chat_architecture.md)
8. [intervention_system.md](./intervention_system.md)
9. [ai_readiness.md](./ai_readiness.md)
10. [current_roadmap.md](./current_roadmap.md)

## Navigation card

| Role | Start here |
| --- | --- |
| Developer | [current_architecture.md](./current_architecture.md), [db_architecture.md](./db_architecture.md), [timeline_architecture.md](./timeline_architecture.md), [chat_architecture.md](./chat_architecture.md), [intervention_system.md](./intervention_system.md) |
| Coach / product | [product_vision.md](./product_vision.md), [behavioral_semantics.md](./behavioral_semantics.md), [ux/coaching_philosophy.md](./ux/coaching_philosophy.md), [ux/low_pressure_engagement.md](./ux/low_pressure_engagement.md) |
| AI assistant | [ai_readiness.md](./ai_readiness.md), [behavioral_semantics.md](./behavioral_semantics.md), [timeline_architecture.md](./timeline_architecture.md), [intervention_system.md](./intervention_system.md), [ai/ai_constraints.md](./ai/ai_constraints.md) |
| Migration / change work | [current_roadmap.md](./current_roadmap.md), [phases](./phases), [db/projections.md](./db/projections.md), [prompts/migration_prompts.md](./prompts/migration_prompts.md), [open_risks.md](./open_risks.md) |

The subfolders add focused detail:

- [phases](./phases)
- [db](./db)
- [ai](./ai)
- [prompts](./prompts)
- [ux](./ux)

## Update rule

When implementation changes:

- update the relevant doc in the same change
- keep the doc factual and concrete
- do not add aspirational architecture that is not in the repo

## Why this exists

PsyBalance is an event-first coaching product. The long-term risk is not only code drift,
but interpretation drift: semantics, projections, intervention rules, and AI assumptions
can silently diverge from the actual system.

This folder is the anti-drift layer.
