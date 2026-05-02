# PsyBalance — Clean Architectural Snapshot

**Generated:** 1 May 2026  
**Status:** Phase 4 complete, documentation foundation active

---

## 1. Product Summary

**PsyBalance** — мобильное приложение (Flutter + Supabase) для асинхронного коучинга и трекинга привычек.

| Параметр | Значение |
|----------|----------|
| **Тип** | Mobile app (Flutter + Supabase) |
| **Целевая модель** | Async coach + habit tracker |
| **Цена** | €60/month (80% coach, 20% platform) |
| **Целевое время** | ≤2 минуты/день |

### Core Hypothesis

Пользователи не могут устойчиво снизить вес, потому что не меняют **behavioral autopilot** в областях:
- Nutrition
- Sleep
- Stress
- Activity
- Relationships

**Solution:** Асинхронный коучинг + легкий ежедневный трекинг.

---

## 2. Current Architecture

```
Flutter UI
   -> Supabase RPCs / direct queries
   -> Postgres source tables
   -> append-only behavior_events timeline
   -> cached projections and snapshots
   -> coach UI, client UI, and AI-ready read layers
```

### Data Access Layer

- Supabase client queries
- Security-definer RPCs для write paths
- Direct read queries для projections и timelines

### Behavioral Core (source tables)

- `task_activity` — append-only behavioral event stream
- `messages` — realtime chat messages
- `conversations` — chat threads
- `behavior_events` — unified behavioral timeline
- `coach_workqueue_items` — coach workqueue
- `coach_interventions` — coach interventions

### Derived Views

- `build_behavior_snapshot(uuid)` — behavior snapshot
- `evaluate_coach_workqueue()` — coach workqueue evaluation
- `plan_items.status` — derived projection

---

## 3. Phase Status

| Phase | Name | Status | Key Deliverable |
|-------|------|--------|-----------------|
| **1** | Task Event Migration | ✅ Complete | `task_activity` → `behavior_events` → `plan_items.status` |
| **2** | Realtime Chat | ✅ Complete | Persistent realtime chat with read state |
| **3** | Behavior Timeline | ✅ Complete | Unified `behavior_events` feed + snapshots |
| **4** | Intervention System | ✅ Complete | Coach interventions with attribution |

### Phase 4 Goals (Current)

- Documentation foundation / master context system
- Durable memory for future changes
- AI-ready read layers over timeline and snapshots

---

## 4. Key Principles

### Event-First Architecture

> Behavioral facts are captured as events before they are interpreted.  
> The system prefers source facts over UI state.

### Append-Only Where It Matters

> The canonical behavioral timeline is append-only.  
> Existing facts are not rewritten just because a projection changes.

### Projections Are Cached Views, Not Truth

> Fields like `plan_items.status`, `conversations.last_message_at`, and  
> `coach_workqueue_items` exist because they are useful projections.  
> They must never be treated as the original source of behavior.

### Explainability Over Cleverness

> Every derived signal should be explainable in plain language.  
> If a rule cannot be described to a coach, it is probably too opaque.

### Human Coach Judgment Stays Central

> The system can organize, summarize, and surface evidence.  
> It must not replace the coach with autonomous action.

### Low-Pressure Interaction

> Support should preserve dignity and avoid pressure to reply.  
> The product is allowed to be helpful; it is not allowed to be coercive.

---

## 5. Event Semantics

### Task Events

| Event | Meaning |
|-------|---------|
| `task_completed` | Task was completed |
| `task_skipped` | Task was explicitly skipped |
| `task_reopened` | Task became active again after being closed |
| `task_auto_closed` | Task was closed by rule, not by human |

### Message Events

| Event | Meaning |
|-------|---------|
| `message_sent` | Message was authored and stored |
| `message_read` | Receiver read the message |

### Check-in Events

| Event | Meaning |
|-------|---------|
| `checkin_submitted` | Client check-in recorded |
| `emotional_checkin_submitted` | Check-in variant with emotional signal |

### Intervention Events

| Event | Meaning |
|-------|---------|
| `intervention_created` | Coach intervention row inserted |
| `intervention_responded` | Client responded to intervention |
| `intervention_expired` | Response window passed without response |

### Operational Events

- `reflection_prompt_sent`
- `reengagement_prompt_sent`
- `coach_recommended_task`
- `risk_flagged`
- `streak_changed`

---

## 6. Timeline Architecture

### Data Flow

```
task_activity (source)
        ↓
   record_task_event(...)
        ↓
   behavior_events (append-only)
        ↓
   rebuild_task_projection(...)
        ↓
   plan_items.status (cached projection)
```

### Key Invariants

1. **task_activity = append-only behavioral event stream** — raw task actions stored
2. **plan_items.status = derived projection** — rebuilt from source activity
3. **behavior_events = unified behavioral timeline** — canonical event feed
4. **Persistent realtime chat implemented** — via Supabase realtime + RPC

---

## 7. Constraints

### What We DO

- ✅ Low-friction daily use (≤2 min/day)
- ✅ Coach judgment stays central
- ✅ No autonomous therapy behavior
- ✅ No pressure-to-reply mechanics
- ✅ No hidden manipulation or addiction optimization
- ✅ Explainable AI
- ✅ Low-pressure async coaching

### What We DON'T

- ❌ No overengineering
- ❌ No addictive mechanics
- ❌ No hidden psychological scoring
- ❌ No clinical language (use operational instead)

---

## 8. Key References

### Core Documentation

- [current_architecture.md](docs/current_architecture.md) — System shape and layers
- [core_principles.md](docs/core_principles.md) — Operating style constraints
- [behavioral_semantics.md](docs/behavioral_semantics.md) — Canonical event meanings
- [tech_constraints.md](docs/tech_constraints.md) — Platform and product constraints

### Phase Documentation

- [phase_1_task_event_migration.md](docs/phases/phase_1_task_event_migration.md) — Task event model
- [phase_2_realtime_chat.md](docs/phases/phase_2_realtime_chat.md) — Chat implementation
- [phase_3_behavior_timeline.md](docs/phases/phase_3_behavior_timeline.md) — Unified timeline
- [phase_4_intervention_system.md](docs/phases/phase_4_intervention_system.md) — Coach interventions

### Database Schema

- [ai_db_schema.sql](ai_db_schema.sql) — Authoritative schema
- [db/behavior_events.md](docs/db/behavior_events.md) — Behavior events table
- [db/task_activity.md](docs/db/task_activity.md) — Task activity table
- [db/conversations.md](docs/db/conversations.md) — Chat threads

---

## 9. Known Bottlenecks

| # | Bottleneck | Impact | Status |
|---|------------|--------|--------|
| 1 | Projection evaluation cost (`evaluate_coach_workqueue()`) | Acceptable for MVP | Monitor |
| 2 | Multiple timeline surfaces | Canonical feed + UI timelines | Needs boundary clarity |
| 3 | Realtime vs reload | Change notifications + explicit reloads | Simple but not minimal |
| 4 | Manual metadata construction | Shared semantics helper exists | Future features need wiring |

---

## 10. Technical Debt (Intentionally Postponed)

- Projection evaluation optimization for larger cohorts
- Timeline surface consolidation
- Network path optimization for chat
- Automated metadata wiring for new features

---

*This snapshot reflects the real implementation state. Documentation, prompts, and future plans are useful only if they reflect the repo. If a feature is not in code or SQL, treat it as future work.*