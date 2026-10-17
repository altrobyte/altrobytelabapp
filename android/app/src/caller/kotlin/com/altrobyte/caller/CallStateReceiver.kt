package com.altrobyte.caller

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.provider.Settings
import android.telephony.TelephonyManager
import org.json.JSONObject
import kotlin.concurrent.thread

/** Watches the phone's call state. While a lead is ringing, shows who it is (Overlay). When a call ends, reads the call
 *  log for how long it lasted and whether anyone picked up, and hands that to the app, which opens "Log this call".
 *  Nothing is recorded: only the number, the direction and the length of the call. */
class CallStateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        @Suppress("DEPRECATION")
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        val ctx = context.applicationContext
        val store = CallerStore(ctx)
        val prev = store.lastState
        val now = System.currentTimeMillis()
        // With the call log permission Android sends each change twice, once with the number and once without.
        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (prev != "ringing") {
                    store.lastState = "ringing"
                    store.callStartedAt = now
                    store.ringNumber = null
                }
                if (number != null && store.ringNumber == null) {
                    store.ringNumber = number
                    Overlay.showFor(ctx, number, goAsync())
                }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                if (prev != "offhook") {
                    if (prev != "ringing") {
                        store.callStartedAt = now
                        store.ringNumber = null // dialling out
                    }
                    store.offhookAt = now
                    store.lastState = "offhook"
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                Overlay.hide()
                if (prev == null || prev == "idle") return
                store.lastState = "idle"
                val pending = goAsync()
                thread {
                    try {
                        Thread.sleep(1500) // the call log entry is written a moment after the call ends
                        ended(ctx, store, prev)
                    } catch (e: Exception) {
                        // A call we could not read is a call the caller logs by hand.
                    } finally {
                        pending.finish()
                    }
                }
            }
        }
    }

    private fun ended(ctx: Context, store: CallerStore, prev: String) {
        val since = store.callStartedAt.takeIf { it > 0 } ?: (System.currentTimeMillis() - 3600_000L)
        val event = fromCallLog(ctx, since - 60_000L) ?: guess(store, prev, since)
        val phone = event.optString("phone")
        if (last10(phone).length != 10) return
        val expected = store.expected() == last10(phone)
        if (expected) store.clearExpected()
        event.put("expected", expected)
        store.setPendingCall(event.toString())

        val entry = store.directoryEntry(phone)
        val lead = expected || entry != null
        val saved = event.optString("contact_name").isNotBlank()
        val type = event.optString("type")
        Handler(Looper.getMainLooper()).post {
            val activity = CallerActivity.live
            if (activity != null) activity.deliverPending()
            // The after-call card, like a caller-ID app's: for a lead, or a number nobody has saved (it may be a new
            // enquiry). Not for a missed ring, and not for the caller's own saved contacts.
            val worthACard = type != "missed" && (lead || !saved)
            when {
                worthACard && activity?.onScreen == true -> Unit // the sheet opens in the app itself
                worthACard && Settings.canDrawOverlays(ctx) -> Overlay.showAfterCall(ctx, event, entry)
                worthACard && activity != null -> ctx.startActivity(Intent(ctx, CallerActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                !lead && !saved && type == "in" && event.optInt("duration_s") > 0 -> offerToAdd(ctx, phone)
            }
        }
    }

    private fun fromCallLog(ctx: Context, since: Long): JSONObject? {
        if (ctx.checkSelfPermission(Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) return null
        val cols = arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DURATION, CallLog.Calls.DATE,
            CallLog.Calls.CACHED_NAME)
        ctx.contentResolver.query(CallLog.Calls.CONTENT_URI, cols, "${CallLog.Calls.DATE} >= ?", arrayOf(since.toString()),
            "${CallLog.Calls.DATE} DESC")?.use { c ->
            if (!c.moveToFirst()) return null
            val type = when (c.getInt(1)) {
                CallLog.Calls.OUTGOING_TYPE -> "out"
                CallLog.Calls.INCOMING_TYPE -> "in"
                else -> "missed"
            }
            return JSONObject().put("phone", c.getString(0) ?: "").put("type", type).put("duration_s", c.getLong(2))
                .put("started_at_ms", c.getLong(3)).put("known", true).put("contact_name", c.getString(4) ?: "")
        }
        return null
    }

    /** No call log to read: the number is the one we dialled or the one that rang, and whether they picked up is left
     *  for the caller to say. */
    private fun guess(store: CallerStore, prev: String, since: Long): JSONObject {
        val ring = store.ringNumber
        val incoming = ring != null
        val type = if (incoming && prev == "ringing") "missed" else if (incoming) "in" else "out"
        val talked = if (store.offhookAt >= since) (System.currentTimeMillis() - store.offhookAt) / 1000 else 0
        return JSONObject().put("phone", ring ?: store.expected() ?: "").put("type", type).put("duration_s", talked)
            .put("started_at_ms", since).put("known", incoming)
    }

    private fun offerToAdd(ctx: Context, phone: String) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("new_leads", "New leads", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(ctx, 7, Intent(ctx, CallerActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = android.app.Notification.Builder(ctx, "new_leads")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Add ${last10(phone)} as a lead?")
            .setContentText("They are not in the CRM yet. Tap to log the call and add them.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(7, n)
        } catch (e: SecurityException) {
            // Notifications switched off: the app offers it next time it opens.
        }
    }
}
