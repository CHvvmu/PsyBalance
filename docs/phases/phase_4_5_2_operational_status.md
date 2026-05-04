# PHASE 4.5.2 - CHAT OPERATIONAL STATUS

This report summarizes the stabilized chat subsystem after Step 6 and Step 7
validation. The assessment is based on the current Flutter and Postgres code paths
and the passing `flutter test` smoke test, without introducing any architectural
changes.

Core invariant confirmed:

- Postgres remains the single source of truth
- realtime only schedules reloads
- reloads reread canonical DB snapshots
- no optimistic message append exists

## 1. OPERATIONAL CHAT FLOWS

| Flow | Status | Confirmation |
| --- | --- | --- |
| coach -> client messaging | operational | `send_chat_message(...)` commits to `messages`, then the chat page reloads from DB. No local bubble is appended before commit. |
| client -> coach replies | operational | The same send path is used for replies. The reply persists after reload because the UI always rereads the committed row set. |
| persistence after reload | operational | Reloads replace the rendered list from the canonical snapshot; there is no local merge layer that can drift. |
| conversation bootstrap | operational with bounded risk | Bootstrap resolves the conversation from DB and opens the thread safely, but first-open concurrency can still race for one caller and show a transient error. |
| conversation isolation | operational | Realtime subscriptions are filtered by `conversation_id`, and stale callbacks are ignored by bootstrap/conversation guards. |
| realtime-triggered reload | operational with bounded risk | Realtime events do not mutate UI state directly; they only schedule a debounced reload. Delayed delivery can lag, but it does not fake state. |
| read-state convergence | operational | `mark_conversation_messages_read(...)` writes `read_at`, and the screen reloads from the DB snapshot after unread messages are loaded. |
| unread convergence | operational with bounded risk | The backend unread/read model converges through `read_at` and unread-count SQL; the inspected Flutter screens do not currently render a visible unread badge consumer. |
| reload consistency | operational | Repeated reloads render the same DB state without duplicate accumulation. |
| safe empty/loading/error states | operational | The chat page uses explicit loading, empty, and error views and never invents committed state to fill gaps. |

## 2. REMAINING INSTABILITY

Only real remaining instability is listed here. None of these items indicate data
corruption in the current design.

| Item | Nature | Trigger | Actual impact | Severity | Data corruption possible? | User-visible inconsistency possible? | Automatic recovery? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `created_at` tie ordering risk | Architectural limitation | Two messages share the same `created_at` value | Message order can appear unstable across reloads because the query sorts only on `created_at` | bounded | no | yes, ordering can flicker | no guaranteed automatic recovery; a secondary sort key is needed |
| concurrent first-open conversation race | Operational instability | Two clients/processes try to create the first conversation for the same pair at the same time | One caller can hit a transient `unique_violation` / unavailable-chat error while the row is created by the winner | bounded | no, the unique index prevents duplicate rows | yes, transient error state for the losing caller | partial; retry or reopen after the row exists |
| bounded reload race windows | Operational limitation | A realtime event arrives while `_loadMessages(...)` is already in flight | The reload request is coalesced and may be deferred by one debounce cycle | low/bounded | no | yes, a brief stale window is possible | yes, the next scheduled refresh converges |
| stale conversation preview cache | Architectural limitation / bounded stale cache | Message list changes after bootstrap, but `_conversation.lastMessagePreview` is not refreshed by the message reload path | The header subtitle can lag behind the latest committed message even while the body list is correct | low/bounded | no | yes, header only | only on rebootstrap / reopen / future refresh of the conversation snapshot |
| eventual realtime convergence timing | Operational limitation | Realtime delivery is delayed, missed, or resubscription is slow | The UI stays on the last committed snapshot until the next successful reload/bootstrap trigger | low/bounded | no | yes, temporarily | yes if a later event, subscribe success, or reopen occurs; otherwise manual retry is needed |

### Architectural limitation vs operational instability

- `created_at` tie ordering and the stale preview cache are architectural
  limitations in the current query/snapshot shape.
- the first-open race, reload windows, and delayed realtime convergence are
  operational instabilities in the current runtime behavior.

## 3. REALTIME LIMITATIONS

- Does realtime mutate canonical UI state directly? **No.** The callback only
  schedules `_loadMessages(...)`; the list is replaced from the DB snapshot.
- Does realtime safely degrade if events are missed? **Yes, with delayed
  convergence.** The UI does not fabricate state, but it can remain temporarily
  stale until the next reload/bootstrap trigger.
- Is reload path canonical? **Yes.** The screen re-reads `messages` from Postgres
  and renders that snapshot.
- What happens after reconnect? If the channel reaches `subscribed` again, the
  widget schedules a refresh. If reconnect does not succeed, the UI remains on the
  last committed snapshot.
- What happens after delayed delivery? The delayed callback schedules a debounced
  reload and the UI converges to the DB snapshot.
- Can duplicate reloads happen? **Yes.** Both payload callbacks and the subscribed
  status can request refreshes, but the debounce/coalescing logic prevents the
  reloads from turning into duplicate UI state.
- Are duplicate messages possible? **Not from the client-side realtime path.** The
  send path is idempotent on `request_key`, and the chat page never appends local
  message bubbles speculatively.
- Is eventual convergence expected? **Yes.** The model is committed-state-first;
  convergence happens when the next successful reload/bootstrap occurs.

Classification: the current realtime behavior is **acceptable for MVP** and safe in
its failure mode, but it is **not yet production-hardened** because reconnect
observability, ordering tie-breakers, and first-open race hardening remain.

## 4. REMAINING FAKE / LOCAL STATE

The remaining local state is mostly UI bookkeeping or cached DB snapshots, not a
fake commit layer.

| Local state | Classification | Notes |
| --- | --- | --- |
| `_isBootstrapping`, `_isBehaviorLoading`, `_isLoadingMessages`, `_isSendingMessage`, `_isMarkingRead` | harmless UI state | Controls loading indicators, composer disablement, and read/send spinners only. |
| `_bootstrapToken`, `_reloadRequestedWhileLoading`, `_reloadRequestedMarkReadAfterLoad` | harmless lifecycle state | Guards against stale callbacks and coalesces reloads. |
| `_messagesChannel`, `_refreshDebounce`, `_scrollController` | harmless UI/lifecycle state | Subscription, debounce, and scroll bookkeeping only. |
| `_conversationError` | harmless UI state | Drives the error view and retry button. |
| `_messages` | harmless render cache | The rendered list is a local snapshot cache, but it is populated only from DB reads. |
| `_conversation` / `_conversation.lastMessagePreview` | bounded stale cache | DB-backed conversation snapshot cached locally; the preview can lag until the conversation is reloaded. |
| `_behaviorStatus`, `_consistencyStreak`, `_lastCheckInAt` | bounded stale cache | Separate behavior context snapshot; not chat truth. |
| `_pendingSendRequestKey`, `_pendingSendDraft` | harmless local bookkeeping | Helps with idempotent send retries and draft restoration after failure. |
| `_currentUserId` | harmless auth/session state | Derived from the authenticated user context. |

Confirmed:

- no optimistic message append exists
- no temporary local message IDs exist
- no client-side reconciliation layer exists
- no fake unread decrement exists

## 5. RLS / RECONNECT / EDGE CASES

| Edge case | Expected behavior | Code-path behavior | Recovery automatic? | UI safely degrades? |
| --- | --- | --- | --- | --- |
| reconnect behavior | Resubscribe and refresh from the canonical snapshot | If the channel reports `subscribed`, the widget schedules a refresh; there is no separate UI reconnect mode | partially; only if resubscription succeeds | yes, the screen stays on the last committed snapshot |
| stale subscriptions | Old channel should not affect the active conversation | `_disposeRealtimeChannel()` unsubscribes/removes the channel and bootstrap/conversation guards ignore late callbacks | yes | yes |
| delayed callbacks | Update after a short debounce, not with speculative state | `_scheduleRefresh(...)` waits 120 ms, then reloads from DB | yes | yes |
| invalid peer resolution / missing conversation handling | Do not render a fake thread; show loading or error until data is valid | Empty peer data keeps the screen in loading during identity resolution; RPC failure yields a generic unavailable/error path | yes, once route/auth data becomes valid or the user retries | yes |
| RLS-denied reads/writes | Surface an error, do not fabricate commit state | Bootstrap catches load failures, send restores the draft and shows a snackbar, read failures are logged without local mutation | manual retry after auth/permission issues are fixed | yes |
| concurrent first-open conversation | One caller wins, the other can fail transiently | Unique index prevents duplicate conversation rows; losing caller can surface a transient RPC error | partial; retry required | yes |
| partial read-state failure | Keep unread state canonical in DB until the update succeeds | `mark_conversation_messages_read(...)` failure leaves `read_at` unchanged and the UI does not pretend otherwise | yes, on the next successful open/reload | yes |

## 6. TECHNICAL DEBT FOR FUTURE PHASES

### SAFE TO DEFER

- conversation preview synchronization on every message event, because the body
  list is already canonical and only the header subtitle can lag
- unread aggregation cleanup / visible badge consumer alignment, because the
  backend unread truth already converges and the inspected Flutter screens do not
  currently render a badge
- retry-message UX polish for bootstrap/send/mark-read errors, because the current
  failure mode is safe and recoverable

### SHOULD BE ADDRESSED BEFORE SCALE

- deterministic secondary ordering for `messages` (`created_at`, then `id`) to
  remove tie instability
- RPC race hardening for first-open conversation creation so the losing caller can
  re-select the row instead of surfacing a transient error
- automated chat integration tests or a device-level flow harness for send/reload/
  read/reconnect coverage
- reconnect hardening and observability for delayed or missed realtime delivery

## 7. FINAL OPERATIONAL ASSESSMENT

Direct answers:

- coach/client messaging works: **yes**
- persistence works: **yes**
- reload consistency works: **yes**
- read state works: **yes**
- realtime works or safely degrades: **yes**
- no fake optimistic UI exists: **yes**

Overall subsystem state: **stabilized MVP**.

Why this classification fits:

- the core chat contract is now committed-state-first and reload-driven
- the known issues are bounded and non-destructive
- the subsystem is operational, but it is not yet fully production-hardened

