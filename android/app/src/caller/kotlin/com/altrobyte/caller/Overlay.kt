package com.altrobyte.caller

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/** The caller ID card: while a lead is ringing, their name, heat, stage, last note and next step over whatever is on
 *  screen. From the app's own copy of the caller's leads first (instant, works offline); a number not in it is looked
 *  up in the CRM, which knows everyone's leads. */
object Overlay {
    private var view: View? = null
    private val main = Handler(Looper.getMainLooper())

    fun showFor(ctx: Context, number: String, pending: BroadcastReceiver.PendingResult) {
        if (!Settings.canDrawOverlays(ctx)) return pending.finish()
        val store = CallerStore(ctx)
        val entry = store.directoryEntry(number)
        if (entry != null) {
            main.post { show(ctx, entry) }
            return pending.finish()
        }
        thread {
            try {
                lookup(store, last10(number))?.let { e -> main.post { if (store.lastState == "ringing") show(ctx, e) } }
            } catch (e: Exception) {
                // No signal, or not a lead: the phone rings as it always does.
            } finally {
                pending.finish()
            }
        }
    }

    private fun lookup(store: CallerStore, phone: String): JSONObject? {
        if (store.token.isEmpty() || store.baseUrl.isEmpty() || phone.length != 10) return null
        val c = URL("${store.baseUrl}/crm/caller-id/$phone").openConnection() as HttpURLConnection
        c.connectTimeout = 3000
        c.readTimeout = 4000
        c.setRequestProperty("Authorization", "Bearer ${store.token}")
        try {
            if (c.responseCode != 200) return null
            val r = JSONObject(c.inputStream.bufferedReader().readText())
            if (!r.optBoolean("known")) return null
            return JSONObject()
                .put("name", r.optString("name").ifEmpty { phone })
                .put("temperature", r.optJSONObject("heat")?.optString("temperature") ?: "")
                .put("pct", r.optInt("score_pct"))
                .put("stage", r.optString("stage"))
                .put("last_note", r.optString("last_note"))
                .put("next", r.optString("next_step"))
                .put("owner", if (r.optBoolean("mine")) "" else r.optString("owner"))
        } finally {
            c.disconnect()
        }
    }

    private fun dp(ctx: Context, v: Int) = (v * ctx.resources.displayMetrics.density).toInt()

    private fun show(ctx: Context, e: JSONObject) {
        hide()
        val heatColor = when (e.optString("temperature")) {
            "hot" -> Color.parseColor("#F44336")
            "warm" -> Color.parseColor("#FF9800")
            "customer" -> Color.parseColor("#1E8E3E")
            else -> Color.parseColor("#3D6690")
        }
        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(ctx, 18), dp(ctx, 14), dp(ctx, 18), dp(ctx, 14))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(ctx, 16).toFloat()
                setStroke(dp(ctx, 3), heatColor)
            }
            elevation = dp(ctx, 8).toFloat()
        }
        fun line(text: String, size: Float, color: Int, bold: Boolean = false) {
            if (text.isBlank()) return
            card.addView(TextView(ctx).apply {
                this.text = text
                textSize = size
                setTextColor(color)
                maxLines = 3
                if (bold) setTypeface(typeface, Typeface.BOLD)
            })
        }
        val temp = e.optString("temperature").replaceFirstChar { it.uppercase() }
        line("Altrobyte lead calling", 12f, Color.parseColor("#6B7280"))
        line(e.optString("name"), 20f, Color.parseColor("#1F2937"), bold = true)
        line(listOf("$temp ${e.optInt("pct")}%", e.optString("stage")).filter { it.isNotBlank() }.joinToString("  ·  "), 15f, heatColor, bold = true)
        line(e.optString("last_note"), 14f, Color.parseColor("#1F2937"))
        line(e.optString("next").let { if (it.isBlank()) "" else "Next: $it" }, 14f, Color.parseColor("#1A3C5E"), bold = true)
        line(e.optString("owner").let { if (it.isBlank()) "" else "Lead of $it" }, 12f, Color.parseColor("#6B7280"))
        line("Tap to hide", 11f, Color.parseColor("#9CA3AF"))
        card.setOnClickListener { hide() }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP
            y = dp(ctx, 90)
            horizontalMargin = 0.03f
        }
        try {
            ctx.getSystemService(WindowManager::class.java).addView(card, params)
            view = card
        } catch (e: Exception) {
            view = null
        }
    }

    // ── after the call ──────────────────────────────────────────────────────

    private var afterView: View? = null

    /** The card that comes up when a call ends: who it was, how it went, and one tap to mark it (interested, call back,
     *  not interested) or add details. Any button opens the log sheet already filled in with that choice. */
    fun showAfterCall(ctx: Context, event: JSONObject, entry: JSONObject?) {
        hideAfterCall()
        val phone = last10(event.optString("phone"))
        val name = entry?.optString("name")?.takeIf { it.isNotBlank() }
            ?: event.optString("contact_name").takeIf { it.isNotBlank() } ?: phone
        val talked = event.optInt("duration_s")
        val how = when {
            !event.optBoolean("known", true) -> "How did it go?"
            talked > 0 -> "Talked ${if (talked >= 60) "${talked / 60}m " else ""}${talked % 60}s"
            else -> "Not picked up"
        }
        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(ctx, 18), dp(ctx, 14), dp(ctx, 18), dp(ctx, 12))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(ctx, 18).toFloat()
                setStroke(dp(ctx, 2), Color.parseColor("#1A3C5E"))
            }
            elevation = dp(ctx, 10).toFloat()
        }
        fun text(t: String, size: Float, color: String, bold: Boolean = false) = TextView(ctx).apply {
            text = t
            textSize = size
            setTextColor(Color.parseColor(color))
            maxLines = 2
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }
        val top = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        top.addView(text("Altrobyte Caller · call ended", 12f, "#6B7280"),
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(text("✕", 18f, "#6B7280").apply {
            setPadding(dp(ctx, 12), 0, 0, 0)
            setOnClickListener { hideAfterCall() }
        })
        card.addView(top)
        card.addView(text(name, 20f, "#1F2937", bold = true))
        val sub = listOfNotNull(how,
            entry?.let { "${it.optString("temperature").replaceFirstChar { c -> c.uppercase() }} ${it.optInt("pct")}%" },
            entry?.optString("stage")?.takeIf { it.isNotBlank() },
            if (entry == null) "Not a lead yet" else null).joinToString("  ·  ")
        card.addView(text(sub, 14f, "#1A3C5E"))
        entry?.optString("last_note")?.takeIf { it.isNotBlank() }?.let { card.addView(text(it, 13f, "#374151")) }

        // A name, typed right here, for a number the CRM has no name for.
        val needsName = entry == null || entry.optString("name").isBlank() || entry.optString("name") == phone
        val nameBox = if (!needsName) null else EditText(ctx).apply {
            hint = "Their name"
            textSize = 15f
            setSingleLine()
            setText(event.optString("contact_name"))
            setTextColor(Color.parseColor("#1F2937"))
            setPadding(dp(ctx, 12), dp(ctx, 8), dp(ctx, 12), dp(ctx, 8))
            background = GradientDrawable().apply {
                cornerRadius = dp(ctx, 10).toFloat()
                setStroke(dp(ctx, 1), Color.parseColor("#9CA3AF"))
            }
        }
        val said = text("", 13f, "#1E8E3E").apply { visibility = View.GONE }
        if (nameBox != null) {
            val nameRow = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(ctx, 8), 0, 0)
            }
            nameRow.addView(nameBox, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            nameRow.addView(TextView(ctx).apply {
                text = "✓ Save"
                textSize = 15f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Color.WHITE)
                setPadding(dp(ctx, 14), dp(ctx, 10), dp(ctx, 14), dp(ctx, 10))
                background = GradientDrawable().apply {
                    cornerRadius = dp(ctx, 10).toFloat()
                    setColor(Color.parseColor("#1E8E3E"))
                }
                setOnClickListener {
                    val typed = nameBox.text.toString().trim()
                    if (typed.isEmpty()) {
                        nameBox.error = "Type a name"
                        return@setOnClickListener
                    }
                    said.visibility = View.VISIBLE
                    said.text = "Saving…"
                    saveName(ctx, event, typed) { ok ->
                        said.text = if (ok) "Saved: $typed ✓" else "Could not save now. Tap Add details to save it in the app."
                        said.setTextColor(Color.parseColor(if (ok) "#1E8E3E" else "#C62828"))
                        if (ok) main.postDelayed({ hideAfterCall() }, 1500)
                    }
                }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                .apply { marginStart = dp(ctx, 8) })
            card.addView(nameRow)
            card.addView(said)
        }

        fun button(label: String, preset: String, color: String) = TextView(ctx).apply {
            text = label
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor(color))
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(ctx, 8), dp(ctx, 10), dp(ctx, 8), dp(ctx, 10))
            background = GradientDrawable().apply {
                cornerRadius = dp(ctx, 12).toFloat()
                setColor(Color.parseColor("#F3F4F6"))
            }
            setOnClickListener { openLog(ctx, preset, nameBox?.text?.toString()?.trim() ?: "") }
        }
        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(ctx, 10), 0, 0) }
        for ((label, preset, color) in listOf(Triple("🔥 Interested", "interested", "#C62828"),
                Triple("⏰ Call back", "call_back", "#1A3C5E"), Triple("✖ Not interested", "not_interested", "#6B7280"))) {
            row.addView(button(label, preset, color), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                .apply { marginEnd = dp(ctx, 6) })
        }
        card.addView(row)
        card.addView(button(if (entry == null) "➕ Add as lead / add details" else "✎ Add details", "", "#FFFFFF").apply {
            (background as GradientDrawable).setColor(Color.parseColor("#D4500A"))
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            .apply { topMargin = dp(ctx, 8) })

        // Focusable only when there is a name to type (the keyboard needs it); touches outside the card still reach the
        // screen below. At the top, so the keyboard does not cover it.
        val focus = if (nameBox != null) WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        else WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            focus or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP
            y = dp(ctx, 70)
            horizontalMargin = 0.03f
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN
        }
        try {
            ctx.getSystemService(WindowManager::class.java).addView(card, params)
            afterView = card
            android.util.Log.i("AltroCaller", "after-call card shown")
        } catch (e: Exception) {
            afterView = null
            android.util.Log.w("AltroCaller", "after-call card not shown: $e")
        }
    }

    /** Saves the name typed on the card, with this call, straight to the CRM (the same call the phone's sync sends, so
     *  it is one call there, not two). A new number becomes the caller's lead with that name. */
    private fun saveName(ctx: Context, event: JSONObject, name: String, done: (Boolean) -> Unit) {
        val store = CallerStore(ctx)
        val phone = last10(event.optString("phone"))
        val started = event.optLong("started_at_ms")
        thread {
            val ok = try {
                if (store.token.isEmpty() || store.baseUrl.isEmpty() || phone.length != 10) false else {
                    val talked = event.optInt("duration_s")
                    val body = JSONObject()
                        .put("client_id", "dev-$phone-$started")
                        .put("started_at", java.time.Instant.ofEpochMilli(started).toString())
                        .put("duration_s", talked)
                        .put("direction", if (event.optString("type") == "out") "out" else "in")
                        .put("outcome", if (talked > 0) "connected" else "no_answer")
                        .put("name", name)
                    val c = URL("${store.baseUrl}/crm/leads/$phone/calls").openConnection() as HttpURLConnection
                    c.requestMethod = "POST"
                    c.doOutput = true
                    c.connectTimeout = 8000
                    c.readTimeout = 15000
                    c.setRequestProperty("Content-Type", "application/json")
                    c.setRequestProperty("Authorization", "Bearer ${store.token}")
                    c.outputStream.use { it.write(body.toString().toByteArray()) }
                    val code = c.responseCode
                    c.disconnect()
                    code in 200..299
                }
            } catch (e: Exception) {
                false
            }
            main.post { done(ok) }
        }
    }

    /** Opens the app on the log sheet for this call, with the card's choice (and any name typed) in it. */
    private fun openLog(ctx: Context, preset: String, typedName: String = "") {
        val store = CallerStore(ctx)
        store.takePendingCall()?.let { raw ->
            store.setPendingCall(JSONObject(raw).put("preset", preset).put("typed_name", typedName).toString())
        }
        hideAfterCall()
        ctx.startActivity(Intent(ctx, CallerActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP))
    }

    fun hideAfterCall() {
        val v = afterView ?: return
        afterView = null
        main.post {
            try {
                v.context.getSystemService(WindowManager::class.java).removeView(v)
            } catch (e: Exception) {
                // Already gone.
            }
        }
    }

    fun hide() {
        val v = view ?: return
        view = null
        main.post {
            try {
                v.context.getSystemService(WindowManager::class.java).removeView(v)
            } catch (e: Exception) {
                // Already gone.
            }
        }
    }
}
