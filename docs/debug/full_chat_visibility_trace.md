# Full Chat Visibility Trace

## What I verified

- Live Supabase base URL: `https://hxgynzqihkwirkdkbyhu.supabase.co`
- Real authenticated client and coach sessions were found in local Chrome storage.
- I verified the runtime chain with authenticated REST probes against the live project.
- I could **not** introspect live `pg_policies` / grants directly from this workspace because there is no DB shell or Supabase CLI connection available here.

That means the live findings below are based on actual authenticated REST behavior, then compared with the canonical repo schema.

---

## Canonical repo schema expected for chat

These are the repo definitions the runtime is supposed to follow:

- `public.users` select/update visibility: [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L97-L156)
- `public.clients` select/update/delete visibility: [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L503-L549)
- `public.conversations` participant visibility: [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L1766-L1797)
- `public.messages` participant visibility: [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L1945-L2018)
- `get_or_create_direct_conversation(p_peer_user_id)` RPC: [ai_db_schema.sql](/d:/vibeCoder/PsyBalance/ai_db_schema.sql#L2100-L2165)

Those repo rules are the canonical authenticated visibility chain the chat bootstrap expects.

---

## Live authenticated trace

### Client session

`auth.uid()`:

- `9104308b-4c04-44d9-83dd-236b1e2219bf`

Observed live chain:

1. `public.users` self row
   - `GET /rest/v1/users?select=id,role,full_name,avatar_url&id=eq.9104308b-4c04-44d9-83dd-236b1e2219bf`
   - result: `200 OK`, `1 row`
   - status: OK

2. `public.clients` self row
   - `GET /rest/v1/clients?select=id,user_id,coach_id,created_at&user_id=eq.9104308b-4c04-44d9-83dd-236b1e2219bf&order=created_at.desc&limit=1`
   - result: `200 OK`, `0 rows`
   - effect: client peer resolution stops here

3. peer coach `public.users` row
   - `GET /rest/v1/users?select=id,role,full_name,avatar_url&id=eq.39c4501e-2806-4264-b24f-ee4edb07515a`
   - result: `200 OK`, `1 row`
   - status: OK

4. `get_or_create_direct_conversation(p_peer_user_id)`
   - `POST /rest/v1/rpc/get_or_create_direct_conversation`
   - result: `404`
   - error: `PGRST202`
   - meaning: function not found in schema cache

5. `public.conversations`
   - `GET /rest/v1/conversations?...`
   - result: `404`
   - error: `PGRST205`
   - meaning: table not found in schema cache

6. `public.messages`
   - `GET /rest/v1/messages?select=id&limit=1`
   - result: `200 OK`, `0 rows`
   - meaning: table is reachable through REST, but no visible rows surfaced in this probe

### Coach session

`auth.uid()`:

- `39c4501e-2806-4264-b24f-ee4edb07515a`

Observed live chain:

1. assigned `public.clients` rows
   - `GET /rest/v1/clients?select=id,user_id,coach_id,created_at&coach_id=eq.39c4501e-2806-4264-b24f-ee4edb07515a&order=created_at.desc`
   - result: `200 OK`, `2 rows`
   - includes the current client row `user_id=9104308b-4c04-44d9-83dd-236b1e2219bf`

2. client `public.users` row
   - `GET /rest/v1/users?select=id,role,full_name,avatar_url&id=eq.9104308b-4c04-44d9-83dd-236b1e2219bf`
   - result: `200 OK`, `1 row`
   - status: OK

3. `get_or_create_direct_conversation(p_peer_user_id)`
   - `POST /rest/v1/rpc/get_or_create_direct_conversation`
   - result: `404`
   - error: `PGRST202`
   - meaning: function not found in schema cache

4. `public.conversations`
   - `GET /rest/v1/conversations?...`
   - result: `404`
   - error: `PGRST205`
   - meaning: table not found in schema cache

5. `public.messages`
   - `GET /rest/v1/messages?select=id&limit=1`
   - result: `200 OK`, `0 rows`

---

## Exact failing point by side

### Client side

- The owning client cannot see its own row in `public.clients`.
- That is the first hard failure in the client chat resolution chain.
- This is a live visibility failure on the `clients` SELECT path, not an auth/session absence problem.

### Coach side

- The coach can see assigned `public.clients` rows, including the current client.
- The coach then fails at `get_or_create_direct_conversation(...)` because the RPC is missing from the live schema cache.
- `public.conversations` is also missing from the live schema cache, so direct conversation visibility cannot complete.

### Shared impact

- `public.messages` is reachable, but the bootstrap cannot reach a valid conversation id, so message loading never becomes canonical.

---

## What this is and what it is not

### It is

- `public.clients` visibility mismatch on the client side
- live schema drift for `public.conversations`
- live schema drift for `get_or_create_direct_conversation(...)`
- hidden null / unavailable masking in the Flutter runtime

### It is not

- a confirmed missing-grants problem
- an auth identity mismatch problem
- an RPC auth/permission failure

Why:

- `public.users` is visible to both sessions
- the coach can see the client row in `public.clients`
- the RPC fails with `404 PGRST202`, not `401/403`
- `public.conversations` fails with `404 PGRST205`, not a permission error

---

## Hidden null masking locations in the runtime

### 1. Client chat identity resolution

[lib/app/router/app_router.dart](/d:/vibeCoder/PsyBalance/lib/app/router/app_router.dart#L505-L545)

- `maybeSingle()` on `public.clients` turns a real row absence / RLS-filtered result into `null`.
- `maybeSingle()` on `public.users` for the coach does the same.
- If the client row is missing, `_peerUserId` stays empty and the page never reaches the RPC.
- The `catch` only logs, so the user sees no explicit cause.

### 2. Dashboard coach card

[lib/features/dashboard/dashboard_page.dart](/d:/vibeCoder/PsyBalance/lib/features/dashboard/dashboard_page.dart#L1382-L1446)

- A missing `public.clients` row becomes `_coach = null` and `_errorMessage = null`.
- That is why the UI falls back to: `Мы покажем здесь связь, когда она появится.`
- This masks the same visibility problem as a benign empty state.

### 3. Role lookup fallback

[lib/features/auth/auth_service.dart](/d:/vibeCoder/PsyBalance/lib/features/auth/auth_service.dart#L65-L101)

[lib/features/auth/auth_service.dart](/d:/vibeCoder/PsyBalance/lib/features/auth/auth_service.dart#L415-L427)

- `maybeSingle()` on `public.users` for role lookup falls back to metadata or a default client role.
- If users visibility ever fails, the app can silently continue with a guessed role.

### 4. Chat bootstrap

[lib/features/chat/chat_page.dart](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L222-L287)

[lib/features/chat/chat_page.dart](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L353-L365)

- Empty `peerUserId` keeps the page in loading state instead of surfacing the missing relation.
- RPC `null` becomes `StateError('Conversation RPC returned no data')`, then the bootstrap catch collapses it to `Чат пока недоступен`.

### 5. Message load

[lib/features/chat/chat_page.dart](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L402-L440)

- Any load error becomes the generic `Не удалось загрузить переписку` state.

### 6. Mark-read / send paths

[lib/features/chat/chat_page.dart](/d:/vibeCoder/PsyBalance/lib/features/chat/chat_page.dart#L536-L614)

- These also collapse concrete backend errors into generic UI feedback.
- They are not the bootstrap blocker here, but they use the same masking pattern.

---

## Live drift vs repo schema

| Object | Repo expectation | Live REST observation | Classification |
| --- | --- | --- | --- |
| `public.users` | self / linked visibility | `200`, visible to both sessions | OK |
| `public.clients` | self or coach SELECT | client session: `200`, `0 rows`; coach session: `200`, `2 rows` | live visibility mismatch on client side |
| `public.conversations` | participant SELECT + insert | `404 PGRST205`; live SQL also reported `relation "public.conversations" does not exist` | physically absent in live DB |
| `public.messages` | participant SELECT + insert/update/delete | `200`, `0 rows` in probe | exists; chat bootstrap still cannot complete without conversations |
| `get_or_create_direct_conversation(...)` | SECURITY DEFINER RPC | `404 PGRST202` | missing from live schema exposure because its canonical block was not fully applied |
| `send_chat_message(...)` | SECURITY DEFINER RPC | `404 PGRST202` when probed | missing from live schema exposure because its canonical block was not fully applied |
| `mark_conversation_messages_read(...)` | SECURITY DEFINER RPC | `404 PGRST202` when probed | missing from live schema exposure because its canonical block was not fully applied |

Because `public.users`, `public.clients`, and `public.messages` all answered through REST, the global `public` schema exposure is already on. The failure is object-specific: `public.conversations` is physically missing, the chat RPC block is missing, and the client-side `public.clients` self-row is still missing.

---

## Minimal safe live fix

1. Restore the canonical `public.clients` SELECT visibility for the owning client (`user_id = auth.uid()`) so the client can resolve the coach peer.
2. Recreate `public.conversations` and the canonical chat RPC block (`get_or_create_direct_conversation`, `send_chat_message`, `mark_conversation_messages_read`) from the repo schema.
3. Leave `public.messages` RLS intact; do **not** disable RLS and do **not** introduce service_role access.

The canonical recovery SQL is in [live_chat_schema_reapply.sql](/d:/vibeCoder/PsyBalance/live_chat_schema_reapply.sql#L1-L608).

If the objects already exist in the database but PostgREST is stale, the safe fix is a schema-cache refresh, not an architectural change.

---

## Bottom line

The runtime chat failure is **not** only a `public.clients` problem, but `public.clients` is still one concrete live failure.

The full chain is currently broken by **two separate live issues**:

1. client-side `public.clients` self-visibility is missing
2. `public.conversations` and the chat RPC block are absent from live DB / exposure

`public.users` is working, so auth identity itself is not the primary issue.

`public.messages` is reachable, but it cannot help until a conversation exists.
