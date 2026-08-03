# ALTROBYTE LAB — PROJECT CONTEXT (READ THIS FIRST, ALWAYS)

## What This Project Is
Altrobyte Lab is a public EdTech platform for **Embedded Systems,
IoT, Circuit Design, Electronics, Firmware, PCB, and AI/ML for
hardware.** Built by Altrobyte Automation Pvt. Ltd., Indore.

Live URL: altrobytelab.web.app

This is a standalone product. Do not reference, compare to, or pull
patterns from any other Altrobyte project unless explicitly told to.

## CRITICAL — CONTENT DOMAIN (violated once already, do not repeat)

Altrobyte Lab is 100% about: **Embedded Systems, IoT, Circuit Design,
Electronics, Firmware, PCB, AI/ML for hardware.**

Altrobyte Lab is NEVER about: Maths, Reasoning, English, General
Knowledge, Current Affairs, or any generic exam-prep subject.

If any instruction would default to Maths/Reasoning/GK/Current
Affairs/English content — stop and re-read this file before
generating any category, quiz topic, or practice test subject.

### Correct "Practice Tests" categories (implemented):
- Embedded C
- Electronics Fundamentals
- ESP32 / Microcontrollers
- IoT Protocols (MQTT, HTTP, WebSocket, BLE)
- Circuit Design & PCB
- Sensors (ADC/DAC, LDR, IR, etc.)
- AI/ML for Embedded (TinyML, Edge AI, OpenCV)
- FreeRTOS / Real-Time Systems

(Same UI/card pattern — only content and labels match this domain.)

## CORE ARCHITECTURE DECISION (do not revisit without asking)
Single-page feed, like Unstop.com — NOT landing-page-then-login-
then-dashboard. Homepage IS the feed. (`/` route = `StudentHomeScreen`,
old separate `landing_page.dart` was deleted.)
- Login is ONLY a button, top-right. Never a redirect gate on page load.
- Sidebar: icon-based nav, always visible.
- Content in horizontal-scroll card rows.
- Login triggers ONLY contextually — confirmed rule for this project:
  - Browsing/previewing topics and rows: always public, no login.
  - **Actually generating/starting an AI practice test: login required**
    (confirmed decision — quota is tracked per student account for
    Groq API cost control; anonymous/unlimited generation was
    explicitly rejected as abuse-prone).
  - Opening Training Modules content: login required (institute-scoped).
  - Saving progress, enrolling, paid content playback: login required.

## AUTH — PRIMARY PATH IS GOOGLE SIGN-IN
`lib/services/google_auth_service.dart` is the single "Sign in with
Google" entry point for all three roles (super_admin / admin /
student) — the backend resolves the role from the Google account's
email. WhatsApp OTP delivery proved unreliable; `/whatsapp-login`
still exists but is not the primary path. Firebase Auth
(`lib/firebase_options.dart`) backs the popup flow.

## WHAT'S BUILT SO FAR
- [x] Firebase project deployed (altrobytelab.web.app)
- [x] Auth: Google Sign-In (all roles) + Firebase Auth; student and
      super-admin surfaces are the visible ones. Admin/Manager routes
      exist but are reached via `/admin-access` and `/super-access`.
- [x] Public feed homepage (single page, no separate landing page)
      with sidebar nav, horizontal-scroll rows, contextual login gates
- [x] Practice Tests + Coming Soon content in the deeptech/embedded/
      IoT domain (was wrongly Maths/Reasoning/GK — fixed)
- [x] Training Modules — 5 tables + API, module > topic > subtopic >
      content item, progress tracking, paid enrollment + admin
      enrollment export (`module_purchase_section.dart`)
- [x] Dev Tools hub (`/student/dev-tools`) — MQTT Tester (MqttBrowserClient
      over WSS, pre-filled with the real ESP32 workshop topic pattern),
      HTTP Tester, WebSocket Tester, BLE Tester. All public, no login.
- [x] Experiments — admin authoring (`experiment_edit_screen`) +
      student browse/detail/attempt, with a code viewer
- [x] Test Series — admin + student surfaces (`/student/test-series`)
- [x] AI Mock Interview (`/student/mock-interview`) — role selection,
      per-question answer scoring, finish + history
- [x] Job Board (`/jobs`) — public listing with category/domain/
      location/experience filters, detail page, apply flow, admin
      application review + CSV export
- [x] Events (`/events`) — public listing/detail, registration,
      admin CRUD + attendee list/export
- [x] Live Sessions (`/live-sessions`) — public listing/detail, paid
      registration with coupon validation, payment verification,
      receipt, admin CRUD + attendee list/export
- [x] Pricing / subscription plans (`/pricing`, `/plans`) with an
      admin editor (`/super/pricing`)
- [x] Payments — Cashfree Checkout via their JS SDK
      (`lib/services/cashfree_checkout.dart` + `web/index.html`; a raw
      redirect to their hosted page is rejected, the SDK is the only
      reliable path). UPI QR fallback asset in `assets/images/`.
- [x] Company/marketing pages — CMS-backed via
      `company/pages/:slug` and `company/items`: `/about`, `/founder`,
      `/about-app`, `/contact`, `/terms`, `/refunds`, `/placements`,
      `/institutes`, `/clients`, `/services`, `/products`, `/blog`
- [x] Partner/institute onboarding enquiries (`/partner`) + admin
      inbox (`/super/enquiries`)
- [x] Platform Users (`/platform-users`) — admin roster of
      `student_users` with per-user activity drill-down
- [x] Student Activity summary screen (`/student/activity`)
- [x] Image upload widget + Firebase Storage rules (`storage.rules`)
- [x] Branded landing per institute slug (catch-all `/:slug` route)
- [ ] Course catalog browsing (public preview) — still NOT BUILT as a
      separate `courses` table. Training Modules + Live Sessions
      currently cover paid content. Do not build catalog UI with
      fake/hardcoded course data.

## WHAT MUST STAY GATED (login required)
- Actually generating/starting an AI Practice Test (quota tracking)
- Training Modules — opening content + progress saving
- AI Mock Interview sessions
- Job applications, event/live-session registration
- Paid content playback, enrollment/payment flow

## WHAT MUST STAY PUBLIC (no login, ever)
- Entire homepage feed — browsing all rows/cards
- Practice Tests row — seeing the topic cards (not generating one)
- Dev Tools (MQTT/HTTP/WebSocket/BLE testers)
- Job/Event/Live-Session listings and detail pages (not registering)
- All company/marketing pages, pricing page, partner enquiry form

## TENANT ISOLATION — KNOWN GAP (not yet fixed)
This backend (Railway + Neon Postgres) is SHARED with a different
product (AltroCoach, a multi-tenant coaching-institute SaaS). There
is currently no `ALTROBYTE_TENANT_ID` scoping — Altrobyte Lab's
institute/admin/super-admin rows live in the same shared tables
(`coaching_institutes`, `super_admins`, etc.) as AltroCoach's real
customers. This has not caused a known incident, but it is a real
architectural gap, not yet resolved. Do not modify AltroCoach's
routes/schema/UI while working on Altrobyte Lab; flag before doing
any deeper tenant-isolation refactor.

## TECH STACK (do not introduce new stack without asking)
- Backend: FastAPI (Python) — D:/Projects/altrocoach-backend (shared)
- Frontend: Flutter web — D:/flutterprrojects/altrobytelab
  (~39k lines Dart, `provider` + `go_router`, l10n en/hi)
- DB: PostgreSQL (Neon)
- Hosting: Firebase (altrobytelab.web.app), Firebase Auth + Storage
- Payments: Cashfree
- AI: Groq (Llama) for quiz generation and mock interviews
- API base URL is `--dart-define=API_BASE_URL` overridable
  (`lib/constants/api_constants.dart`)

## BEFORE STARTING ANY NEW TASK
1. Re-read this file fully, especially the CONTENT DOMAIN section.
2. If any instruction would add non-embedded/IoT/circuit/AI content,
   stop and ask for confirmation.
3. After finishing a task, update "What's Built So Far" before
   ending the session.
