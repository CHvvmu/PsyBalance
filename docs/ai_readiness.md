# AI Readiness

PsyBalance is AI-ready in the sense that the system already preserves the evidence
needed for explainable assistance. It is not AI-autonomous.

## What AI should consume

AI should prefer these signals in order:

1. `behavior_events` for sequence and causation
2. `coach_workqueue_items.behavior_snapshot` for current explainable routing state
3. `coach_interventions.metadata` for intervention context and outcome tracing
4. `messages` for message content and read state
5. `task_activity` for raw task facts

## What AI must not infer aggressively

AI must not turn sparse operational signals into clinical claims.

Do not infer:

- diagnosis
- treatment need
- emotional dependence
- hidden motivation as fact
- manipulative engagement intent

## Explainability requirements

Every AI suggestion should be explainable in plain language.
That means the output should be able to answer:

- what evidence was used?
- which event(s) triggered the suggestion?
- what window was considered?
- what made this lower or higher priority?

The current codebase already supports that style through snapshots, metadata, and
outcome labels.

## Human-in-the-loop constraint

The current product expects a coach to make the final call.
AI may assist with:

- summarizing the behavioral state
- drafting a low-pressure message
- highlighting an outcome pattern
- clustering repeated signals

AI may not:

- send support messages on its own
- escalate emotionally on its own
- change the meaning of an event
- hide the evidence chain from the coach

## Why the timeline matters for AI

AI needs chronology, not only counts.

The timeline lets the system reason about:

- what happened before the intervention
- what happened inside the response window
- whether the client returned after silence
- whether a task completion followed support
- whether repeated avoidance is emerging

Without the timeline, AI would collapse into noisy classification.

## Allowed AI tasks in the current architecture

- explain a snapshot
- draft a gentle intervention for coach approval
- summarize a recent response window
- identify a likely repeat-avoidance pattern
- describe evidence without making diagnosis claims

## Not allowed

- autonomous therapy
- manipulative engagement optimization
- hidden scoring UI
- pressure to reply
- direct message sending without a coach decision

