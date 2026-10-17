package com.altrobyte.caller

import android.content.Context
import org.json.JSONObject

/** What the native side keeps between broadcasts: the lead directory for caller ID, the login for looking a number up,
 *  the call the app just dialled, the phone's last call state, and events waiting for the Flutter side. */
class CallerStore(context: Context) {
    private val p = context.applicationContext.getSharedPreferences("altrobyte_caller", Context.MODE_PRIVATE)

    var lastState: String?
        get() = p.getString("last_state", null)
        set(v) = p.edit().putString("last_state", v).apply()

    var stateSince: Long
        get() = p.getLong("state_since", 0)
        set(v) = p.edit().putLong("state_since", v).apply()

    var callStartedAt: Long
        get() = p.getLong("call_started_at", 0)
        set(v) = p.edit().putLong("call_started_at", v).apply()

    var offhookAt: Long
        get() = p.getLong("offhook_at", 0)
        set(v) = p.edit().putLong("offhook_at", v).apply()

    var ringNumber: String?
        get() = p.getString("ring_number", null)
        set(v) = p.edit().putString("ring_number", v).apply()

    fun expect(phone: String) = p.edit().putString("expect_phone", last10(phone)).putLong("expect_at", System.currentTimeMillis()).apply()

    /** The number the app dialled in the last two hours, if any. */
    fun expected(): String? {
        val at = p.getLong("expect_at", 0)
        return if (System.currentTimeMillis() - at < 2 * 3600_000L) p.getString("expect_phone", null) else null
    }

    fun clearExpected() = p.edit().remove("expect_phone").remove("expect_at").apply()

    fun setDirectory(json: String, token: String, baseUrl: String) =
        p.edit().putString("directory", json).putString("token", token).putString("base_url", baseUrl).apply()

    fun directoryEntry(phone: String): JSONObject? = try {
        JSONObject(p.getString("directory", "{}") ?: "{}").optJSONObject(last10(phone))
    } catch (e: Exception) {
        null
    }

    val token: String get() = p.getString("token", "") ?: ""
    val baseUrl: String get() = p.getString("base_url", "") ?: ""

    var reminders: String
        get() = p.getString("reminders", "[]") ?: "[]"
        set(v) = p.edit().putString("reminders", v).apply()

    fun setPendingCall(json: String) = p.edit().putString("pending_call", json).apply()
    fun takePendingCall(): String? = p.getString("pending_call", null)?.also { p.edit().remove("pending_call").apply() }

    fun setPendingOpen(phone: String) = p.edit().putString("pending_open", phone).apply()
    fun takePendingOpen(): String? = p.getString("pending_open", null)?.also { p.edit().remove("pending_open").apply() }
}

fun last10(phone: String): String {
    val d = phone.filter { it.isDigit() }
    return if (d.length >= 10) d.takeLast(10) else d
}
