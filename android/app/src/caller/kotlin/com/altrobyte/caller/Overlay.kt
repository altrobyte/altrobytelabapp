package com.altrobyte.caller

import android.content.BroadcastReceiver
import android.content.Context
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
