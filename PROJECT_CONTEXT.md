# ALTROBYTE LAB — PROJECT CONTEXT (READ THIS FIRST, ALWAYS)

## What This Project Is
Altrobyte Lab is a public EdTech platform for **Embedded Systems,
IoT, Circuit Design, Electronics, Firmware, PCB, and AI/ML for
hardware.** Built by Altrobyte Automation Pvt. Ltd., Indore.

Live URL: altrobytelab.web.app

This is a standalone product. Do not reference, compare to, or pull
patterns from any other Altrobyte project unless explicitly told to.

## NAMING
The student-facing AI-generated practice feature is called **Custom Test
Series** everywhere in the UI. "AI Practice"/"Practice Tests" is the old
name — don't reintroduce it. The combined tab is just "Test Series".

## CRITICAL — CONTENT DOMAIN (violated once already, do not repeat)

Altrobyte Lab is 100% about: **Embedded Systems, IoT, Circuit Design,
Electronics, Firmware, PCB, AI/ML for hardware.**

Altrobyte Lab is NEVER about: Maths, Reasoning, English, General
Knowledge, Current Affairs, or any generic exam-prep subject.

If any instruction would default to Maths/Reasoning/GK/Current
Affairs/English content — stop and re-read this file before
generating any category, quiz topic, or practice test subject.

### Correct "Custom Test Series" categories (implemented):
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
email. Firebase Auth (`lib/firebase_options.dart`) backs the popup flow.

WhatsApp OTP login is FULLY BUILT on both sides and deliberately hidden,
not broken or missing — don't rebuild it:
- `POST /student/standalone/request-otp` + `/verify-otp` (registers a new
  number with a name, or logs an existing one in)
- `POST /auth/request-otp` + `/auth/verify-otp` for institute owners
- `whatsapp_login_screen.dart` at `/whatsapp-login`
- Sender: Botko (`automation.altrobyte.com/internal/send-otp`, needs
  `INTERNAL_SEND_SECRET`), falling back to the Meta Graph API with the
  `altron_auth_otp` template
Turning it on is a UI change of well under 100 lines (un-hide the side
rail's login item, add the option alongside Google). BLOCKED ON A
DEDICATED WHATSAPP NUMBER being provisioned — decided 2026-08-07, keep
Google as the only path until then.

Enabling it also fixes a real gap: Google gives no phone number, so those
accounts carry a placeholder and every Cashfree payment had to ask for a
mobile at checkout. It is likewise the prerequisite for any lead
management or WhatsApp marketing work.

## WHAT'S BUILT SO FAR
- [x] Firebase project deployed (altrobytelab.web.app)
- [x] Auth: Google Sign-In (all roles) + Firebase Auth; student and
      super-admin surfaces are the visible ones. Admin/Manager routes
      exist but are reached via `/admin-access` and `/super-access`.
- [x] Public feed homepage (single page, no separate landing page)
      with sidebar nav, horizontal-scroll rows, contextual login gates
- [x] Custom Test Series + Coming Soon content in the deeptech/embedded/
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
      admin editor (`/super/pricing`). Self-serve purchase is wired:
      `subscription_plans.tier_key` IS the billing plan id — '999' (Plus)
      and '9999' (Elite) are chargeable, 'free' is the default, and
      'institution'/'industry' route to the `/partner` enquiry form.
      Flow: `POST /student/subscribe {plan}` → Cashfree JS SDK with the
      returned `payment_session_id` → poll `POST /student/subscription/verify`.
      Backend fixes this needed (in `student_subscriptions.py`): verify used
      to look the order up in `transactions` by `student_id` (NULL for
      Google-only Lab students) and by `purpose='student_premium'` (subscribe
      writes `student_plan_999`), read two `get_limits()` keys that don't
      exist, and set `plan='premium'` which `is_premium_active()` never
      matches — so it could never activate anything. The pending order/tier is
      now pinned to `student_subscriptions.pending_order_id/pending_plan`.
      Deployed and verified against production.
- [x] Plan tiers: `free`, `999` (Plus), `4999` (Pro), `9999` (Elite), plus
      sales-assisted `institution`/`industry`. The paid tiers sell ACCESS
      (workshops, videos, GitHub projects, Challenges) — not AI quota. Quota
      is a fair-use ceiling, never the pitch.
      | | Free | 999 Plus | 4999 Pro | 9999 Elite |
      |---|---|---|---|---|
      | Custom Test Series | 5/mo | 30/mo | 90/mo | 150/mo |
      | Quiz attempts | 1/day | 5/day | 20/day | 50/day |
      | Mock interviews | 1/mo | 3/mo | 5/mo | 15/mo |
      | Live workshops | 0 | 0 | 4/mo | 30/mo |
      | Learning modules | 1 | all | all | all |
      | Videos + resources | — | — | yes | yes |
      | GitHub projects | 0 | 3 | all | all |
      | Paid Challenges | — | — | yes | yes |
      Elite = everything unlocked; a multi-month programme is covered for as
      long as the subscription runs, so there is NO per-session "included"
      flag and no separate workshop purchase.
      Buyable for 1/3/6 months, discounted 10%/15% on the total.
      `GET /student/subscription/quotes` is the ONLY price source — never
      re-derive a discount client-side.
      All limits + prices live in `global_settings`; changing one needs no
      deploy. `price_label` is DERIVED from `global_settings`, so editing it
      via `/super/pricing` is rejected.

      Rules that the last round of bugs came from — do not break these:
      - Tier order lives in ONE list (`PLAN_ORDER` in student_subscriptions.py)
        and every per-tier limit resolves by name. Adding a tier must not need
        a new branch in any caller.
      - NO TIER IS UNCAPPED. An uncapped plan is an open tap on the Groq bill,
        and one compromised paid account could drain it.
      - Gate on the token's `student_users.id`, NEVER on `student_id` (the
        institute `students` row) — Google-only Lab students have no such row,
        so a `student_id`-keyed gate silently applies to nobody.
      - Locked content is STRIPPED server-side (url + body set to null). A
        locked item whose URL still ships is not locked.
      - Free's one module and Plus's three GitHub projects are picked
        deterministically by course order — same content free for everyone, no
        per-student state.
      - Cashfree 400s on a bad name/phone/email. `cashfree.py` coerces all
        three centrally (`person_name`, `phone_number`, `email_or_none`);
        Google accounts have NO phone, so checkout asks for one and saves it.

## AI (GROQ) — THE REAL PLATFORM CONSTRAINT
Groq's limit is PER KEY, PER DAY, and the key is shared with AltroCoach's
institutes. Whoever spends it first blocks everyone — an admin who generated
nothing still gets refused. That is NOT a plan quota: telling the user to
upgrade would take their money and change nothing (`tests.py` says so now).
- Add capacity with a pool, no deploy needed: `GROQ_API_KEY_2` (or 3/4/5), or
  commas inside `GROQ_API_KEY`. Generation fails over on a daily-limit 429.
- Per-minute 429s deliberately do NOT rotate keys — they clear by themselves,
  and rotating would burn the whole pool for nothing.
- Student Custom Test Series generation is OFF (`student_custom_test_enabled`)
  precisely because it spends this key. Turn it on only with headroom.

## TESTS — RUN THESE, THEY EXIST NOW
- Backend: `pytest tests/ -q` — 156 fast tests, no DB needed. Covers tier
  resolution, quotas, pricing/discount math and the Cashfree name/phone/email
  coercion. `tests/conftest.py` is deliberately lazy: it does NOT import
  `main` at module scope and does NOT run `init_db()` autouse, so pure unit
  tests run without the full stack or a database. Keep it that way.
- Frontend: `flutter test` — the pricing payload contract.
- After ANY backend deploy: `python scripts/smoke.py` (exits non-zero on
  failure). This is what catches a push Railway never deployed — which has
  happened, silently, twice.

## BACKEND GOTCHA — `init_db()` IS ONE TRANSACTION
A single failing statement in `init_db()` aborts the whole transaction
(everything after it dies with "current transaction is aborted"),
startup raises, the Railway healthcheck fails, and Railway keeps
serving the PREVIOUS deployment. The push looks like it did nothing —
no error surfaces anywhere in the app. This has already cost one
silent no-op deploy. Put new schema changes and backfills in
`_LATE_MIGRATIONS` in `database.py` instead: they run on their own
autocommit connection, one statement at a time, each in a try/except.

## WHAT MUST STAY GATED (login required)
- Actually generating/starting an AI Practice Test (quota tracking)
- Training Modules — opening content + progress saving
- AI Mock Interview sessions
- Job applications, event/live-session registration
- Paid content playback, enrollment/payment flow

## WHAT MUST STAY PUBLIC (no login, ever)
- Entire homepage feed — browsing all rows/cards
- Custom Test Series row — seeing the topic cards (not generating one)
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
