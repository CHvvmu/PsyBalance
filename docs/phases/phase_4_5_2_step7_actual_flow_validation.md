# Phase 4.5.2 - Step 7 - Actual Flow Validation

## Validation basis

This step validates the stabilized chat system by tracing the current Flutter and
Postgres runtime paths directly in the repo. No refactor was introduced.

Evidence used:

- chat screen lifecycle, load, send, read, and realtime code in
  [lib/features/chat/chat_page.dart](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart)
- route entry points in
  [lib/app/router/app_router.dart](/d:/vibeCoder/PsyBalance/lib/app/router/app_router.dart)
- chat RPCs, unread projection SQL, and ingest triggers in
  [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql)
- current architecture notes in
  [docs/chat_architecture.md](/d:/vibeCoder/PsyBalance/docs/chat_architecture.md)
  and [docs/db/realtime_architecture.md](/d:/vibeCoder/PsyBalance/docs/db/realtime_architecture.md)

Verification note:

- `flutter test` passed during this step.
- No dedicated device-level integration harness exists in the repo, so the flow
  validation here is based on code-path tracing plus the passing smoke test.

## Overall verdict

The current chat implementation matches the committed-state-first design:

- no optimistic message append
- no local message cache reconciliation
- realtime events only trigger reloads
- reloads always read canonical DB state
- state replacement is snapshot-based, so duplicate accumulation does not occur

Two bounded caveats remain:

1. message ordering is only ordered by `created_at`, so equal timestamps can still
   be tie-unstable
2. first-open conversation creation can still fail transiently for one concurrent
   caller if both try to create the same row at once

No operationally risky chat corruption was identified in the traced code path.

## Reproduced inconsistencies

No end-to-end runtime inconsistency was reproduced in this workspace. The bounded
issues below were identified by direct code-path inspection rather than by a live
device harness:

- possible ordering tie on equal `created_at`
- transient first-open conversation race
- no visible unread badge consumer in the checked Flutter screens

---

## Flow A - Coach opens chat, sends a message, client reloads and still sees it

### Trace

```text
open chat
-> route push to CoachChatPage
-> initState
-> bootstrap
-> conversation resolve
-> initial DB snapshot load
-> DB snapshot render
-> subscribe
-> send
-> DB insert commit
-> realtime callback
-> reload snapshot
-> DB snapshot render
-> page reload/re-entry
-> reload snapshot again
-> DB snapshot render again
```

Important sequencing detail:

- the initial message snapshot is loaded before the realtime subscription is
  established, but the subscription status callback immediately schedules a
  refresh after the channel is live
- the composer stays disabled until bootstrap completes, so there is no user
  path that allows a send before the chat is ready

### Verified invariants

- Message visibility starts only after the RPC commit returns a database row.
- Realtime callbacks never append local bubbles; they only schedule refreshes.
- Reloads reread the canonical `messages` table snapshot.
- Re-entering the screen after reload renders the same DB message set again.
- Duplicate accumulation does not happen because the list is replaced, not merged.
- No temporary local message IDs are rendered.
- Loading, empty, and error states remain safe fallbacks.

### Evidence

- route entry: [app_router.dart#L411-L425](/d:/vibeCoder/PsyBalance/lib/app/router/app_router.dart#L411-L425)
- bootstrap and state reset: [chat_page.dart#L68-L91](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L68-L91)
- conversation resolve and initial load: [chat_page.dart#L353-L381](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L353-L381)
- snapshot load and read trigger: [chat_page.dart#L384-L433](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L384-L433)
- realtime subscription and stale-event guards: [chat_page.dart#L453-L533](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L453-L533)
- send path with request key reuse and no local append: [chat_page.dart#L556-L615](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L556-L615)
- commit-first RPC and idempotent insert logic: [ai_db_schema.sql#L2168-L2292](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L2168-L2292)
- request key unique index: [ai_db_schema.sql#L1941-L1943](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L1941-L1943)
- message ingest trigger: [ai_db_schema.sql#L3792-L3796](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L3792-L3796)
- safe loading / empty / error states: [chat_page.dart#L925-L1044](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L925-L1044)

---

## Flow B - Client replies, coach sees reply after reload, ordering stays stable enough

### Trace

```text
client reply
-> send_chat_message commit
-> realtime event for the conversation
-> reload snapshot from DB
-> DB snapshot render
-> coach sees reply
-> page reload/re-entry
-> reload snapshot again
-> DB snapshot render again
```

### Verified invariants

- The reply persists after reload because the screen never depends on local
  optimistic state.
- The list order is deterministic for normal message streams because each reload
  re-sorts from the same DB data.
- There is no inversion caused by merging local and remote lists, because no
  merge layer exists.
- Scroll behavior after inbound/reloaded messages is consistent: every successful
  load calls `_scrollToBottom()`.

### Ordering check

Current query:

```dart
.order('created_at', ascending: true)
```

Assessment:

- operationally sufficient for ordinary single-write flows
- not strictly deterministic if two rows share the same `created_at`
- Postgres will not guarantee a stable tie order without a secondary sort key

So the proposed hardening is valid in principle:

```dart
.order('created_at', ascending: true)
.order('id', ascending: true)
```

But it was not applied in this step, because no live instability was reproduced
and the phase explicitly asked to avoid ordering changes unless needed.

### Severity

- bounded

### Evidence

- ordered DB load: [chat_page.dart#L402-L433](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L402-L433)
- bottom scroll after each load: [chat_page.dart#L419-L432](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L419-L432)
- message record parsing and rendering: [chat_page.dart#L1133-L1184](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L1133-L1184)
- conversation message ordering in the UI: [chat_page.dart#L1046-L1074](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L1046-L1074)
- supporting message indexes: [ai_db_schema.sql#L1937-L1943](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L1937-L1943)

---

## Flow C - Unread conversation opens, read_at updates, unread projection converges

### Trace

```text
conversation closed
-> inbound message arrives
-> unread projection updates
-> open conversation
-> load canonical messages
-> markConversationMessagesRead
-> DB update of read_at
-> unread projection converges
-> badge clears in any consumer of the unread projection
```

### Verified invariants

- `read_at` is the canonical unread truth in the database.
- The chat screen does not locally decrement unread state.
- `mark_conversation_messages_read(...)` only updates `read_at`; it does not fake
  a local read projection.
- If the mark-read RPC fails, the screen logs the error and leaves the DB state
  untouched until the next successful refresh or reopen.
- Delayed realtime delivery still converges because subscription status and later
  change callbacks both schedule reloads.

### Important observation

The checked Flutter codebase does not currently surface a visible unread badge or
counter consumer in `lib/`. The backend unread projection exists and is canonical,
but there is no in-repo Flutter widget that directly renders it yet. That means the
"badge clears" step is validated at the DB/projection layer, not as a visible UI
element on the inspected screens.

### Severity

- bounded

### Evidence

- read-state RPC: [ai_db_schema.sql#L2295-L2326](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L2295-L2326)
- unread projection functions: [ai_db_schema.sql#L2328-L2370](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L2328-L2370)
- read-state mark in chat page: [chat_page.dart#L419-L432](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L419-L432)
- mark-read RPC call and failure behavior: [chat_page.dart#L536-L554](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L536-L554)
- read ingest trigger: [ai_db_schema.sql#L3798-L3907](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L3798-L3907)
- message read behavior-events ingest: [ai_db_schema.sql#L4096-L4157](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L4096-L4157)

---

## Additional validations

### A. Rapid open/close switch

Validated sequence:

```text
open chat A
-> bootstrap token A
-> old channel A created
leave immediately
-> dispose unsubscribes and removes channel A
open chat B
-> bootstrap token B
-> old callback for A arrives late
-> callback is ignored by bootstrap token and conversation id guards
```

Result:

- no cross-chat message leakage
- no stale callback UI update
- no stale reload mutation
- old subscriptions are disposed correctly

### Severity

- harmless

### Evidence

- dispose and channel cleanup: [chat_page.dart#L86-L91](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L86-L91)
- bootstrap-side channel disposal: [chat_page.dart#L241-L243](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L241-L243)
- subscription guards: [chat_page.dart#L460-L493](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L460-L493)

### B. Reload convergence

Validated behavior:

```text
same DB state
-> same UI state on load
-> repeated reloads replace the list with the same snapshot
-> no duplicate accumulation
-> no disappearing messages
```

Result:

- repeated reloads converge to the same view
- `_reloadRequestedWhileLoading` only coalesces pending refreshes; it does not
  introduce speculative state

### Severity

- harmless

### Evidence

- snapshot replacement: [chat_page.dart#L402-L432](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L402-L432)
- refresh coalescing: [chat_page.dart#L393-L449](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L393-L449)

### C. First-open conversation race

Validated behavior:

```text
two clients/processes
-> concurrently call get_or_create_direct_conversation
-> both may observe no existing row
-> one insert wins
-> the other can hit a unique_violation
-> the losing caller surfaces the chat error state
-> retry succeeds after the row exists
```

DB protection:

- unique index on `(client_id, coach_id)` prevents duplicate conversations

Current surfaced UI state:

- `_bootstrap()` catches the RPC error and sets the generic chat unavailable
  message
- the screen remains recoverable via retry

### Severity

- bounded

### Evidence

- unique index: [ai_db_schema.sql#L1761-L1764](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L1761-L1764)
- conversation RPC insert path: [ai_db_schema.sql#L2100-L2165](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L2100-L2165)
- chat bootstrap error fallback: [chat_page.dart#L269-L286](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L269-L286)

---

## Minimal recommended fixes

None were required to satisfy the current phase constraints.

Optional hardening notes only, if the product later needs them:

1. add a secondary `id` sort key for message ordering if strict tie determinism is
   required
2. expose an unread badge consumer on a screen that actually reads the unread
   projection if that UI is still intended
3. catch `unique_violation` inside `get_or_create_direct_conversation` and re-select
   the already-created row if the transient race becomes too noisy

---

## Final status

The chat system currently behaves as a committed-state-first, reload-driven,
conversation-isolated flow.

Confirmed:

- DB remains the source of truth
- realtime only requests reloads
- reloads are canonical
- read state converges through `read_at`
- no optimistic state layer was introduced
- no client-side message duplication path was found

Open but bounded:

- tie ordering under equal `created_at`
- transient first-conversation race failure
- unread badge consumer is not present in the checked Flutter screens
