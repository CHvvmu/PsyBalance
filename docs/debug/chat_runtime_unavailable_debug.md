# Chat Runtime Unavailable Debug

## Symptom

In `flutter run -d chrome`, the runtime behavior reported by the user is:

- Coach page: `Чат пока недоступен`
- Client page: `Мы покажем здесь связь, когда она появится`

Meanwhile, task plans and task status exchange still work, which strongly suggests
the task/coach relationship exists and the failure is in chat peer resolution or
chat bootstrap, not in the broader account model.

## Required runtime trace

The actual runtime path to inspect is:

```text
client opens chat
-> _ResolvedClientChatPage
-> clients query
-> coach resolution
-> peerUserId creation
-> CoachChatPage bootstrap
-> get_or_create_direct_conversation RPC
-> messages load
```

## What the code shows right now

### Client-side route resolution

The client chat route is built in `lib/app/router/app_router.dart` and always
creates `_ResolvedClientChatPage(clientId: authService.currentUser?.id ?? '')`.

The resolver then:

1. reads `public.clients` with `user_id = current auth uid`
2. extracts `coach_id`
3. reads `public.users` with `id = coach_id`
4. writes `_peerUserId = coachId`
5. renders `CoachChatPage(peerUserId: _peerUserId, behaviorUserId: widget.clientId)`

### Dashboard fallback state

The client dashboard shows the text `Мы покажем здесь связь, когда она появится.`
only when `_coach == null` and `_errorMessage == null`.

That means the dashboard text is **not** itself a chat bootstrap failure. It is a
separate symptom of the coach-relationship card not resolving during dashboard load.

## Observed runtime values

The captured `flutter run -d chrome` session produced these relevant values:

- `userId=9104308b-4c04-44d9-83dd-236b1e2219bf`
- `ROLE LOAD: loaded role=client from users table`
- `DASHBOARD AVATAR LOAD ROW: ... hasRow=true`
- `COACH SUPPORT RELATIONSHIP LOADED: ... hasRow=false row=null`
- `COACH SUPPORT RELATIONSHIP EMPTY: ...`

Observed meaning:

- the authenticated `public.users` row exists
- the app can read the user's own profile row
- the client-to-coach link row in `public.clients` was not returned for the
  logged-in client in this runtime

The run did **not** capture a successful `CoachChatPage` bootstrap trace because
the client-side relationship lookup never resolved a coach peer.

## Exact failing condition most consistent with the current code

The actual runtime failure point observed in this run is **the `public.clients`
lookup returning no row** for the current client.

Why this is the strongest fit:

- The client dashboard and the client chat resolver both depend on the same
  `clients.user_id -> clients.coach_id` relationship.
- The dashboard fallback is explicitly shown when the row cannot be loaded.
- `_ResolvedClientChatPage` needs that same row to create `peerUserId`.
- If `_peerUserId` remains empty, `CoachChatPage` bootstrap aborts before the
  conversation RPC.

### Exact bootstrap abort condition

In `CoachChatPage._bootstrap()`:

```text
if (peerUserId.isEmpty) {
  _isBootstrapping stays true
  return
}
```

So an empty peer id prevents the chat from ever reaching:

- `get_or_create_direct_conversation`
- `messages` load

This is a code-path conclusion derived from the runtime state above, not a direct
chat-bootstrap log from the captured run.

## Actual runtime values to capture with the temporary logs

The temporary debug logs added in this step will print the following values:

### Client route / identity path

- current auth uid on dashboard load
- `clients` query result for `user_id = current auth uid`
- resolved `coach_id`
- `users` row for `coach_id`
- resolved `_peerUserId`

### Chat bootstrap path

- bootstrap start token
- current auth uid
- incoming `peerUserId`
- incoming `behaviorUserId`
- conversation RPC start/result/row/error
- conversation id returned from RPC
- message load row set
- realtime subscribe status

## Runtime diagnosis categories

### 1. Data issue

Possible if `public.clients` has no row for the current client, or the row has an
empty/null `coach_id`.

### 2. RLS issue

Possible if the client can load tasks but not `clients` or `users` rows. The
policy setup allows `clients` select for `user_id = auth.uid()` or `coach_id =
auth.uid()`, and `users` select for the same relationship model, so RLS should be
checked if the runtime logs show query failure rather than empty data.

### 3. Routing issue

Less likely. The client route does build `_ResolvedClientChatPage` and then
`CoachChatPage`; the problem would be the data fed into that route, not the route
class itself.

### 4. Identity mismatch

Possible and important. The code assumes `clients.coach_id` stores `users.id`.
That is consistent with:

- `public.clients.coach_id uuid references public.users(id)`
- `public.users.id uuid primary key references auth.users(id)`

So the identity model is:

- `auth.users.id` == `public.users.id`
- `clients.user_id` and `clients.coach_id` both point at `public.users.id`

If runtime data was created using some other coach identifier, the resolver will
fail.

### 5. Peer resolution issue

Most likely runtime bucket if the client dashboard shows the fallback text and the
client chat never resolves a coach peer.

### 6. Bootstrap abort

Likely end state for the chat page if `_peerUserId` is empty: bootstrap returns
early, leaving the page effectively unavailable.

## RLS checks from schema

Observed policy shape in the schema:

- `public.clients` select is allowed for the owning client or their coach
- `public.users` select is allowed for self, linked client, or linked coach
- `public.conversations` select is allowed for participants
- `public.messages` select is allowed for participants

So if the runtime data is valid, RLS should not block the normal client->coach
lookup chain.

If runtime logs show `clients` query success but `coach_id` is empty, that is a data
issue, not RLS.

If runtime logs show query exceptions, that is either RLS or auth/session state.

## Minimal safe fix

No architecture change is needed yet.

The minimal safe unblock is:

1. repair or create the missing `public.clients` row for the current client/coach
   pair
2. confirm the row contains a non-empty `coach_id` that points at `public.users.id`
3. re-run the client dashboard and chat route to verify that `_peerUserId` is
   populated and bootstrap reaches `get_or_create_direct_conversation`

If the row is missing, this is a **data issue**, not a chat architecture issue.

If the row exists but `coach_id` is empty, fix the row data.

If the row exists but the `users` record is missing, create/fix the coach user
record.

## Most likely conclusion

At present, the observed exact failing step is:

```text
public.clients lookup -> no row returned -> _peerUserId stays empty
-> CoachChatPage bootstrap aborts before get_or_create_direct_conversation
```

That would explain:

- client dashboard fallback text
- chat unavailable state
- working task/coach relationship elsewhere
