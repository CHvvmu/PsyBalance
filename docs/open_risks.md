# Open Risks

These are the main production and architecture risks that remain visible in the current system.

## 1. Semantic drift

Risk: code, SQL, and docs can drift apart over time.

Why it matters: the system is only safe if the meaning of events stays stable.

Mitigation: keep docs updated alongside schema and code changes.

## 2. Projection cost at larger scale

Risk: periodic workqueue evaluation may become expensive if the number of coach-client
pairs grows substantially.

Why it matters: the current cron-style projection is simple, but not infinitely cheap.

Mitigation: keep the projection model explainable and measure before optimizing.

## 3. Dual timeline surface

Risk: the UI timeline and `behavior_events` timeline could be confused as the same thing.

Why it matters: one is a presentation aggregation; the other is the canonical feed.

Mitigation: keep the distinction explicit in docs and code.

## 4. Realtime reliance on committed rows

Risk: the chat experience depends on Supabase realtime publication and committed data.

Why it matters: if publication settings change, the UI will fall back to slower reload paths.

Mitigation: keep reload-on-change logic and avoid assuming perfect push delivery.

## 5. Outcome ambiguity

Risk: short replies can be misread as meaningful engagement when they are only acknowledgements.

Why it matters: intervention interpretation must remain conservative and dignity-preserving.

Mitigation: keep the outcome labels evidence-based and surface the response window.

## 6. Metadata consistency

Risk: different write paths can drift in the metadata keys they attach.

Why it matters: AI readiness depends on stable metadata fields.

Mitigation: reuse the shared semantics helpers and avoid ad hoc maps.

## 7. Overfitting to signals

Risk: the team may start treating derived labels as stronger truth than they are.

Why it matters: the model should stay operational, not diagnostic.

Mitigation: keep raw events visible in the evidence chain.

