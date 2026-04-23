# PsyBalance — AI Tasks (Harvi Code Execution Plan)

## 0. Execution Rules (CRITICAL)

* Execute tasks **strictly in order**
* Do NOT skip steps
* After each task:

  * validate result
  * ensure no breaking errors
* Do NOT add features outside scope
* Prefer **working simple implementation** over ideal architecture

---

## 1. Project Setup

### 1.1 Initialize Project

* Create Flutter project
* Setup environments:

  * dev
  * prod (optional for MVP)

### 1.2 Connect Supabase

* Configure:

  * SUPABASE_URL
  * SUPABASE_ANON_KEY
* Verify connection

### ✅ Checkpoint

* App runs
* Supabase connection works

---

## 2. Database Setup (Supabase)

### 2.1 Create Tables

#### users

* id (uuid, PK)
* email
* role (client / coach / administrator)

#### clients

* user_id (FK → users.id)
* coach_id (FK → users.id)

#### check_ins

* id
* user_id
* date
* sleep
* stress
* energy
* mood

#### food_logs

* id
* user_id
* image_url
* meal_type
* created_at

#### plans

* id
* user_id
* week_start

#### plan_items

* id
* plan_id
* title
* status
* proof_image

#### messages

* id
* sender_id
* receiver_id
* text
* image_url
* created_at

---

### 2.2 Storage Setup

* Create bucket:

  * `food_images`
  * `chat_images`

---

### ✅ Checkpoint

* Tables created
* Insert/select works
* Storage upload works

---

## 3. Authentication

### 3.1 Implement Auth

* Email + password:

  * register
  * login
  * logout

### 3.2 Role Handling

* On registration:

  * assign role = `client`
* Add manual role override (for coach/admin)

### 3.3 Password Reset

* Email-based recovery

---

### ✅ Checkpoint

* User can:

  * register
  * login
  * recover password

---

## 4. Onboarding

### 4.1 Create Screens

* Welcome
* Goal selection (simple)
* Basic info (optional)

### 4.2 Save Data

* Link onboarding completion to user

---

### ✅ Checkpoint

* User completes onboarding
* Data saved

---

## 5. Dashboard

### 5.1 Build Dashboard Screen

Show:

* Today check-in status
* Plan progress
* Last message preview

### 5.2 Data Binding

* Fetch:

  * latest check-in
  * current week plan
  * last message

---

### ✅ Checkpoint

* Dashboard loads real data

---

## 6. Daily Check-in

### 6.1 UI

* 4 sliders or emoji inputs:

  * sleep
  * stress
  * energy
  * mood

### 6.2 Submit Logic

* Save to `check_ins`
* One entry per day

---

### ✅ Checkpoint

* Check-in saves correctly
* Duplicate prevention works

---

## 7. Food Photo Diary

### 7.1 Image Upload

* Camera
* Gallery

### 7.2 Tagging

* breakfast / lunch / dinner / snack

### 7.3 Save

* Upload image → Supabase Storage
* Save URL in `food_logs`

---

### ✅ Checkpoint

* Image uploads
* Entry appears in DB

---

## 8. Activity Plan

### 8.1 Display Plan

* Load current week plan
* Show list of tasks

### 8.2 Status Update

* done / not_done / partial

### 8.3 Proof Upload

* Optional image upload

---

### ✅ Checkpoint

* Status updates persist
* Proof images attach correctly

---

## 9. Chat System

### 9.1 Basic Messaging

* Send text
* Receive messages

### 9.2 Image Support

* Upload image → send URL

### 9.3 Realtime (optional MVP-lite)

* Polling acceptable

---

### ✅ Checkpoint

* Messages send/receive
* Chat persists

---

## 10. Coach Panel

### 10.1 Client List

* Show all assigned clients

### 10.2 Client Card

* View:

  * check-ins
  * food logs
  * plan

### 10.3 Plan Editor

* Create/update weekly plan

### 10.4 Chat Access

* Same chat thread

---

### ✅ Checkpoint

* Coach sees clients
* Can edit plans
* Can chat

---

## 11. Risk Detection (Simple)

### 11.1 Logic

* If:

  * ≥2 "not_done"
  * OR no check-ins

→ mark as "risk"

### 11.2 UI

* Highlight risky users

---

### ✅ Checkpoint

* Risk users visible

---

## 12. Admin Panel

### 12.1 Features

* Create coach
* View users
* View subscriptions (mock allowed)

---

### ✅ Checkpoint

* Admin actions work

---

## 13. Notifications

### 13.1 Push

* Daily check-in reminder
* New message

### 13.2 Email

* Onboarding
* Reminder

---

### ✅ Checkpoint

* Notifications delivered

---

## 14. Basic Analytics

### 14.1 Metrics

* ARPU (static/mock OK)
* churn (basic logic)

---

### ✅ Checkpoint

* Metrics visible

---

## 15. Final QA

### 15.1 Full Flow Test

Client:

* onboarding
* check-in
* food log
* plan update
* chat

Coach:

* see client
* edit plan
* chat

---

### 15.2 Data Validation

* No data loss
* Correct relations

---

### 15.3 UX Check

* ≤2 min daily usage
* No friction points

---

## 16. Definition of Done

* All flows work end-to-end
* No critical bugs
* App usable without explanation
* Data persists correctly

---

## 17. Execution Priority

1. Auth
2. Check-in
3. Food log
4. Plan
5. Chat
6. Coach panel
7. Notifications
8. Admin

---

## FINAL RULE

**If something works — DO NOT REFACTOR during MVP phase.**
