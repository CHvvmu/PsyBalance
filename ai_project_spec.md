# PsyBalance — AI Project Specification

## 1. Project Overview

**Name:** PsyBalance
**Type:** Mobile application (Flutter + Supabase)
**Goal (MVP):** Validate “asynchronous coach + habit tracker” model at €60/month with 20% platform fee

### Core Hypothesis

Users fail to lose weight sustainably because they do not change behavioral autopilot:

* Nutrition
* Sleep
* Stress
* Activity
* Relationships

**Solution:**
Asynchronous coaching + lightweight daily tracking (≤2 minutes/day)

---

## 2. Product Concept

### Value Proposition

* Simple daily actions (low friction)
* Continuous coach support (async)
* Behavior-first approach (not diets)

### Pricing Model

* €60/month subscription
* 80% → coach
* 20% → platform

---

## 3. MVP Scope

### Client App Flow

Onboarding → Dashboard → Check-in → Food Log → Plan → Chat → Content

---

## 4. Core Features

### 4.1 Authentication

* Email + password (Supabase Auth)
* Roles:

  * `client`
  * `coach`
  * administrator
* Password reset

---

### 4.2 Client Functionality

#### Daily Check-in

* 4–5 parameters:

  * Sleep
  * Stress
  * Energy
  * Mood (optional)
* UI: sliders or emoji scale
* Time to complete: ≤15 seconds

#### Food Photo Diary

* Add photo via:

  * Camera
  * Gallery
* Tags:

  * breakfast / lunch / dinner / snack
* Max friction: 2 taps

#### Activity Plan

* Weekly plan (set by coach)
* Status per item:

  * done
  * not_done
  * partial
* Optional:

  * Screenshot upload (Google Fit / Apple Health)

#### Chat (1:1)

* Text messages
* Image support
* Async communication

#### Dashboard

* Today summary:

  * check-in status
  * plan progress
  * last coach message
* Progress graphs:

  * weekly
  * monthly

#### Educational Content

* 1 short piece/day (~1 min)
* Static for MVP

---

### 4.3 Coach Panel

#### Client Management

* List of clients
* Client card:

  * check-ins
  * food logs
  * activity stats

#### Risk Filtering

* Flag clients with:

  * multiple "not_done"
  * missing check-ins

#### Plan Editor

* Weekly plan builder
* Drag & drop tasks
* Editable per client

#### Chat

* Same chat as client (shared thread)

#### Templates

* Predefined messages

---

### 4.4 Admin Panel (Minimal)

* Create coaches
* View users
* Subscription overview
* Metrics:

  * ARPU
  * churn

---

### 4.5 Notifications

#### Push

* Daily check-in reminder
* Upcoming call reminder
* New coach message

#### Email

* Onboarding
* Reminders

---

## 5. Tech Stack

### Frontend

* Flutter (iOS + Android)

### Backend

* Supabase:

  * Auth
  * Postgres DB
  * Storage (images)

---

## 6. Data Model (Critical)

### Users

* id
* role (client/coach)
* email

### Clients

* user_id
* coach_id

### CheckIns

* user_id
* date
* sleep
* stress
* energy
* mood

### FoodLogs

* user_id
* image_url
* meal_type
* created_at

### Plans

* id
* user_id
* week_start

### PlanItems

* plan_id
* title
* status
* proof_image (optional)

### Messages

* sender_id
* receiver_id
* text
* image_url
* created_at

---

## 7. UX Constraints (VERY IMPORTANT)

* Max daily interaction: **≤ 2 minutes**
* Max taps per core action: **≤ 2–3**
* No complex forms
* Mobile-first only
* Zero cognitive overload

---

## 9. Acceptance Criteria

### Must Work End-to-End

* User can:

  * register/login
  * complete onboarding
  * submit check-in
  * upload food photo
  * update plan status
  * chat with coach

* Coach can:

  * see clients
  * edit plans
  * send messages

* System:

  * stores all data
  * sends push notifications

---

## 10. AI Development Rules (STRICT)

### General

* Do NOT invent features outside MVP
* Do NOT overengineer
* Prefer simple solutions over scalable ones

### Supabase

* Use normalized schema
* Avoid complex joins (prefer simple queries)
* Use storage for images

### UI

* Reuse components
* Avoid deep navigation
* Keep screens minimal

---

## 11. Definition of Done

* All core flows functional
* No blocking bugs
* Data persists correctly
* App usable without explanation

---

## 12. Future Scope (NOT IN MVP)

* AI coach automation
* Advanced analytics
* Wearable integrations (real-time)
* Marketplace of coaches

---

## 13. Design Reference

https://designer.flutterflow.io/d/001ce605-d179-484b-ad16-b9a1d44853bf
