package com.altrobyte.caller

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** Follow-up reminders: one alarm per lead with a follow-up ahead, a notification when it is due, and the lead opened
 *  when it is tapped. The app replaces the whole set every time the queue changes; a reboot puts them back. */
object Reminders {
    private fun intent(ctx: Context, r: JSONObject?, id: Int): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
        if (r != null) {
            i.putExtra("id", id).putExtra("title", r.optString("title")).putExtra("body", r.optString("body"))
                .putExtra("phone", r.optString("phone"))
        }
        return PendingIntent.getBroadcast(ctx, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun replaceAll(ctx: Context, json: String) {
        val store = CallerStore(ctx)
        val am = ctx.getSystemService(AlarmManager::class.java)
        val old = JSONArray(store.reminders)
        for (i in 0 until old.length()) am.cancel(intent(ctx, null, old.getJSONObject(i).optInt("id")))
        store.reminders = json
        scheduleAll(ctx)
    }

    fun scheduleAll(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val list = JSONArray(CallerStore(ctx).reminders)
        val now = System.currentTimeMillis()
        for (i in 0 until list.length()) {
            val r = list.getJSONObject(i)
            val at = r.optLong("at_ms")
            if (at <= now) continue
            val pi = intent(ctx, r, r.optInt("id"))
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("followups", "Follow-up reminders", NotificationManager.IMPORTANCE_HIGH))
        val id = intent.getIntExtra("id", 0)
        val open = PendingIntent.getActivity(context, id,
            Intent(context, CallerActivity::class.java).putExtra("open_phone", intent.getStringExtra("phone"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(context, "followups")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle(intent.getStringExtra("title") ?: "Follow-up due")
            .setContentText(intent.getStringExtra("body") ?: "Tap to open the lead")
            .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra("body") ?: ""))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
        try {
            nm.notify(id, n)
        } catch (e: SecurityException) {
            // Notifications are off; the lead still shows as due at the top of Today.
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.scheduleAll(context)
    }
}
