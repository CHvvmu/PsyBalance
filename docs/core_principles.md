# Core Principles

These principles describe the operating style of the codebase and should be treated
as stable constraints, not preferences.

## 1. Event first

Behavioral facts are captured as events before they are interpreted.
The system prefers source facts over UI state.

## 2. Append-only where it matters

The canonical behavioral timeline is append-only.
Existing facts are not rewritten just because a projection changes.

## 3. Projections are cached views, not truth

Fields like `plan_items.status`, `conversations.last_message_at`, and
`coach_workqueue_items` exist because they are useful projections.
They must never be treated as the original source of behavior.

## 4. Explainability over cleverness

Every derived signal should be explainable in plain language.
If a rule cannot be described to a coach, it is probably too opaque.

## 5. Human coach judgment stays central

The system can organize, summarize, and surface evidence.
It must not replace the coach with autonomous action.

## 6. Low-pressure interaction

Support should preserve dignity and avoid pressure to reply.
The product is allowed to be helpful; it is not allowed to be coercive.

## 7. Production-safe increments

Changes should be incremental and backward compatible whenever possible.
This is especially important for the schema, RPCs, and projections.

## 8. Real implementation wins

Documentation, prompts, and future plans are useful only if they reflect the repo.
If a feature is not in code or SQL, treat it as future work.

