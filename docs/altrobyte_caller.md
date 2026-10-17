# Altrobyte Caller

The telecallers' Android app. It calls leads, logs every call, and manages follow-ups. The CRM in
`altrocoach-backend` (`crm.py`, `crm_heat.py`, `crm_calls.py`) is the only store. The app keeps a copy of the caller's
queue only so it still opens with no signal.

## Who signs in with what

| Person | Login | Sees |
|---|---|---|
| Telecaller | a **manager** login of the institute | their own leads (`owner` = their email) |
| Team lead | a manager login with the **Team lead** box ticked (`permissions.crm_team = true`) | everyone's numbers, unassigned leads, assigning |
| Admin | the institute admin login (switch "I am the institute admin" on the sign-in screen) | everything, plus labels, people and exports |

Add people in the web CRM: **CRM > headset icon (Calling team) > People**.

## Build the APK

The app is a separate entry point (`lib/caller/caller_main.dart`) and a separate Android flavor (`caller`, app id
`com.altrobyte.caller`), so its call permissions never touch the lab app.

```
flutter build apk --release --flavor caller -t lib/caller/caller_main.dart
```

The APK is written to `build/app/outputs/flutter-apk/app-caller-release.apk`.

Since the flavors were added, an Android build of the lab app needs `--flavor lab`. Web and Windows builds are unchanged.

### Signing (once)

The team installs the APK directly, not from the Play Store, because Play restricts call-log permissions. Every update
must be signed with the same key, or Android refuses to install it over the old one. Keep the key safe.

```
keytool -genkey -v -keystore altrobyte-caller.jks -keyalg RSA -keysize 2048 -validity 10000 -alias caller
```

Then create `android/key.properties` (gitignored):

```
storeFile=../../altrobyte-caller.jks
storePassword=...
keyAlias=caller
keyPassword=...
```

Without `key.properties`, a release build is signed with the debug key. That is fine for a test phone and wrong for the
team.

### Installing on a team phone

1. Send the APK (WhatsApp, Drive or USB) and open it. Android asks to allow installs from that app once.
2. Open Altrobyte Caller and sign in.
3. The first screen explains each permission in plain words. Allow them in order. "Show caller ID over other apps"
   opens an Android settings page: find Altrobyte Caller there and switch it on.
4. On Xiaomi, Oppo, Vivo and Realme phones, also set battery to **No restrictions** for the app. Otherwise the phone
   may stop the follow-up reminders and the caller ID card.

To update, install the new APK over the old one. The phone keeps the login and any unsent logs.

## How it works

- **Today** shows follow-ups due now, then hot, warm, and new uncalled leads, then everyone else, then follow-ups set
  for later, then converted leads. The server sorts it (`crm_calls.bucket`). `lib/caller/queue_order.dart` uses the same
  rule, so a call logged offline moves its lead at once.
- **Call** rings the number directly (`ACTION_CALL`). When the call ends, `CallStateReceiver` reads the call log for the
  length of the call and whether anyone picked up. The app comes back and opens **Log this call**, already filled in.
- **Log this call** is all taps. The defaults fit most calls: no answer suggests a retry in 2 hours, "call back later"
  suggests tomorrow at 11 am, and a new lead who picked up moves to "contacted". One tap on Save usually logs it.
- **Offline**: every log is written to the phone first (`outbox.dart`), then sent. Each log carries an id made on the
  phone, so a log sent twice is saved once. A log that arrives after a newer one is kept as history, but it does not
  undo the newer one.
- **Reminders**: a local alarm and notification at each follow-up time. Tapping it opens that lead. Reminders come back
  after a reboot.
- **Caller ID**: when a lead rings, a card shows their name, heat, stage, last note and next step. The card comes from
  the phone's own copy of the caller's leads, or from `/crm/caller-id` for anyone else's lead. After a call from an
  unknown number, the app offers "Add as a lead?".
- **Score and conversion** come from the CRM. `crm_heat.py` turns call outcomes into the score: interest heard on the
  call raises it, and a run of unanswered calls lowers it. Nobody marks a lead as paid. A paid registration or the
  "enrolled" stage shows "Converted 🎉", credited to whoever last spoke to the lead.
- **No call recording.**

## Backend

New endpoints (all in `crm_calls.py`, tested in `tests/test_crm_calls.py`):

| Endpoint | Who | What |
|---|---|---|
| `GET /crm/my-queue` | caller | their sorted queue (`?owner=` for a team lead) |
| `POST /crm/leads/{phone}/calls` | caller | log a call; also updates the stage, labels, follow-up and note in one transaction |
| `GET /crm/leads/{phone}/timeline` | caller (own leads) | calls, notes and WhatsApp messages in order |
| `GET /crm/caller-id/{phone}` | caller | who is ringing |
| `GET/PUT /crm/labels` | everyone / admin | the labels callers tag leads with |
| `GET /crm/quick-wa`, `POST /crm/leads/{phone}/quick-wa` | caller | fixed WhatsApp messages: inside the 24-hour window as text, outside it through the approved utility templates |
| `GET /crm/team`, `GET /crm/unassigned`, `PUT /crm/assign` | team lead | the team, leads nobody owns, assign (one owner or `round_robin`) |
| `POST /crm/team`, `PUT /crm/team/{login}` | admin | add a caller, make or unmake a team lead, switch a login off |
| `GET /crm/team-stats?days=` | team lead (a caller sees only their own row) | calls, connected %, talk time, follow-ups done and missed, interested, conversions |
| `GET /crm/export.csv?what=leads\|calls` | admin | CSV copy |
| `PUT/POST /crm/export/sheet`, `POST /cron/crm-sheet` | admin / cron | nightly append-only copy of new calls to one Google Sheet |

The tables are created on start in `crm._ensure_tables`: `crm_calls`, plus the new `wa_contacts` columns
`next_followup_at`, `labels`, `last_called_at` and `last_called_by`. The new stage `demo_booked` sits between
"interested" and "enrolled".

### Nightly Google Sheet (optional)

1. Create a Google Cloud service account and download its JSON key. Put the whole JSON in the Railway variable
   `GOOGLE_SHEETS_SA_JSON`.
2. Share the sheet with the service account's email, as Editor.
3. Paste the sheet id in **Calling team > Export**.
4. Add a nightly cron that calls `POST https://edu.altrobytelab.com/cron/crm-sheet` with the header
   `X-Cron-Secret: <CRON_SECRET>`, the same way `/cron/run-daily` is called.

Only calls not yet sent are appended. The sheet is never edited, and nothing is read back from it.

### Settings

- `crm_roadmap_link` (Admin settings): the link that "Send roadmap" sends. Empty means altrobytelab.com/roadmap.
