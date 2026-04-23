# PsyBalance — AI Prompts (Harvi Code Commands)

## 0. Usage Rules (READ FIRST)

* Execute prompts **strictly in order**
* Do NOT merge steps
* After each prompt:

  * run code
  * verify result
* If error → FIX before moving forward
* Do NOT invent features
* Stay within `ai_project_spec.md`

---

## 1. Supabase Initialization

### PROMPT 1.1 — Create Database Schema

```
Create a Supabase PostgreSQL schema for a mobile app "PsyBalance".

Tables:
- users (id uuid PK, email text, role text)
- clients (user_id uuid FK users.id, coach_id uuid FK users.id)
- check_ins (id uuid PK, user_id uuid, date date, sleep int, stress int, energy int, mood int)
- food_logs (id uuid PK, user_id uuid, image_url text, meal_type text, created_at timestamp)
- plans (id uuid PK, user_id uuid, week_start date)
- plan_items (id uuid PK, plan_id uuid, title text, status text, proof_image text)
- messages (id uuid PK, sender_id uuid, receiver_id uuid, text text, image_url text, created_at timestamp)

Requirements:
- Add primary keys
- Add foreign keys
- Use simple indexing on user_id fields
- Keep schema minimal (MVP only)
```

---

### PROMPT 1.2 — Storage Setup

```
Configure Supabase Storage for PsyBalance:

Buckets:
- food_images (public)
- chat_images (public)

Allow upload and read access for authenticated users only.
```

---

## 2. Authentication

### PROMPT 2.1 — Email Auth

```
Implement Supabase email/password authentication in Flutter:

Features:
- register
- login
- logout

After registration:
- insert user into "users" table
- assign role = "client"

Do not use any third-party auth providers.
```

---

### PROMPT 2.2 — Password Reset

```
Add password reset via email using Supabase Auth.

UI:
- email input
- success message

Keep UI minimal.
```

---

## 3. Onboarding

### PROMPT 3.1 — Onboarding Flow

```
Create onboarding screens in Flutter:

Steps:
1. Welcome screen
2. Goal selection (simple options)
3. Finish screen

Save onboarding completion flag for user.

Keep UX very simple (max 2 taps per screen).
```

---

## 4. Dashboard

### PROMPT 4.1 — Dashboard UI

```
Create a Dashboard screen:

Show:
- today's check-in status
- weekly plan progress
- last message preview

Use simple layout:
- top summary
- middle plan
- bottom message preview
```

---

### PROMPT 4.2 — Dashboard Data

```
Fetch and bind data for Dashboard:

- latest check-in (today)
- current week plan
- last message

Do not use complex joins. Use separate queries if needed.
```

---

## 5. Daily Check-in

### PROMPT 5.1 — Check-in UI

```
Create Daily Check-in UI:

Inputs:
- sleep
- stress
- energy
- mood

Use sliders or emoji.

Time to complete ≤15 seconds.
```

---

### PROMPT 5.2 — Save Check-in

```
Save check-in to Supabase:

Rules:
- one entry per user per day
- overwrite if exists

Table: check_ins
```

---

## 6. Food Diary

### PROMPT 6.1 — Upload Image

```
Implement image upload:

Sources:
- camera
- gallery

Upload to Supabase Storage (food_images bucket).
```

---

### PROMPT 6.2 — Save Food Log

```
Save food log:

Fields:
- user_id
- image_url
- meal_type
- created_at

Meal types:
- breakfast
- lunch
- dinner
- snack
```

---

## 7. Activity Plan

### PROMPT 7.1 — Display Plan

```
Display weekly plan for user:

- list of plan_items
- grouped by week

Show status:
- done
- not_done
- partial
```

---

### PROMPT 7.2 — Update Status

```
Allow user to update plan item status:

- done
- not_done
- partial

Save to database immediately.
```

---

### PROMPT 7.3 — Upload Proof

```
Allow optional image upload for plan item:

- upload to storage
- save URL in proof_image
```

---

## 8. Chat

### PROMPT 8.1 — Basic Chat

```
Implement 1:1 chat:

- send message
- receive message

Table: messages

Fields:
- sender_id
- receiver_id
- text
- created_at
```

---

### PROMPT 8.2 — Image in Chat

```
Add image support in chat:

- upload image to chat_images
- send image_url in message
```

---

### PROMPT 8.3 — Message Loading

```
Load chat messages between two users:

- ordered by created_at
- simple polling (no realtime required for MVP)
```

---

## 9. Coach Panel

### PROMPT 9.1 — Client List

```
Create Coach screen:

- list all clients assigned to coach
- show basic info

Table: clients
```

---

### PROMPT 9.2 — Client Details

```
Create Client Detail screen:

Show:
- recent check-ins
- food logs
- plan items
```

---

### PROMPT 9.3 — Plan Editor

```
Allow coach to:

- create weekly plan
- edit plan items
- assign to client

Keep UI simple list-based (no complex drag-drop required for MVP).
```

---

### PROMPT 9.4 — Chat Access

```
Allow coach to open chat with client:

Reuse existing chat system.
```

---

## 10. Risk Detection

### PROMPT 10.1 — Risk Logic

```
Implement simple risk detection:

Conditions:
- 2+ plan_items with status "not_done"
- OR no check-in in last 2 days

Mark user as "risk".
```

---

### PROMPT 10.2 — UI Highlight

```
Highlight risky users in coach client list:

- add visual indicator (badge or color)
```

---

## 11. Admin Panel

### PROMPT 11.1 — Admin Screen

```
Create Admin screen:

Features:
- list users
- create coach (change role)
```

---

## 12. Notifications

### PROMPT 12.1 — Push Notifications

```
Implement push notifications:

Events:
- daily check-in reminder
- new message

Use simple scheduled + trigger-based approach.
```

---

### PROMPT 12.2 — Email Notifications

```
Send email notifications:

- onboarding
- reminders

Use Supabase or external SMTP.
```

---

## 13. Final Validation

### PROMPT 13.1 — End-to-End Test

```
Test full user flow:

Client:
- register
- onboarding
- check-in
- food log
- plan update
- chat

Coach:
- view client
- edit plan
- chat

Fix all blocking issues.
```

---

## FINAL PROMPT — Stabilization

```
Review entire codebase:

- remove unused code
- fix crashes
- ensure all data persists correctly

Do NOT refactor working features.
Focus only on stability.
```
