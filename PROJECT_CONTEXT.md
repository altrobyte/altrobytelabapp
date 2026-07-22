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

### Correct "What's Coming" categories (implemented):
- "IoT & Embedded Hackathons"
- "Embedded/IoT Internships"
- "Product Engineer Job Board"
- "Mentorship with Industry Engineers"

(Same UI/card pattern — only content and labels match this domain.)

## CORE ARCHITECTURE DECISION (do not revisit without asking)
Single-page feed, like Unstop.com — NOT landing-page-then-login-
then-dashboard. Homepage IS the feed. (`/` route = `StudentHomeScreen`,
old separate `landing_page.dart` was deleted.)
- Login is ONLY a button, top-right. Never a redirect gate on page load.
- Sidebar: icon-based nav (Home/Practice/Training/Login), always visible.
- Content in horizontal-scroll card rows.
- Login triggers ONLY contextually — confirmed rule for this project:
  - Browsing/previewing topics and rows: always public, no login.
  - **Actually generating/starting an AI practice test: login required**
    (confirmed decision — quota is tracked per student account for
    Groq API cost control; anonymous/unlimited generation was
    explicitly rejected as abuse-prone).
  - Opening Training Modules content: login required (institute-scoped).
  - Saving progress, enrolling, paid course playback: login required.

## WHAT'S BUILT SO FAR
- [x] Firebase project deployed (altrobytelab.web.app)
- [x] Auth: Student + Super Admin roles only (Admin/Manager login
      removed from visible UI, routes still exist unlinked)
- [x] Training Modules — backend (5 tables + API), 6 screens wired
      to real data (module > topic > subtopic > content item)
- [x] Public feed homepage (single page, no separate landing page)
      with sidebar nav, horizontal-scroll rows, contextual login gates
- [x] Practice Tests + Coming Soon content corrected to deeptech/
      embedded/IoT domain (was wrongly Maths/Reasoning/GK — fixed)
- [x] Dev Tools — MQTT Tester (mqtt_client, MqttBrowserClient over WSS,
      pre-filled with the altrobyte/home/... topic pattern from the
      real ESP32 workshop demo), HTTP Tester (method/headers/body/
      response viewer using the existing `http` package), WebSocket
      Tester (web_socket_channel). All three are real, working,
      public — no login anywhere in the flow. Reachable from a
      "Dev Tools" row on the homepage feed
      (`lib/screens/tools/*_tester_screen.dart`).
- [ ] Course catalog browsing (public preview) — NOT YET BUILT,
      needs a real `courses` table + admin create/edit screen before
      any UI is added (do not build the UI with fake/hardcoded course
      data — same mistake as the old Training Modules build)

## WHAT MUST STAY GATED (login required)
- Actually generating/starting an AI Practice Test (quota tracking)
- Training Modules — opening content + progress saving
- Paid course lesson video/content playback
- Enrollment/payment flow

## WHAT MUST STAY PUBLIC (no login, ever)
- Entire homepage feed — browsing all rows/cards
- Practice Tests row — seeing the topic cards (not generating one)
- Dev Tools (MQTT/HTTP/WebSocket testers), once built
- Course catalog browsing/preview, once built

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
- Frontend: Flutter, web build — D:/flutterprrojects/altrobytelab
- DB: PostgreSQL (Neon)
- Hosting: Firebase (altrobytelab.web.app)
- AI: Groq (Llama) for quiz generation

## BEFORE STARTING ANY NEW TASK
1. Re-read this file fully, especially the CONTENT DOMAIN section.
2. If any instruction would add non-embedded/IoT/circuit/AI content,
   stop and ask for confirmation.
3. After finishing a task, update "What's Built So Far" before
   ending the session.
