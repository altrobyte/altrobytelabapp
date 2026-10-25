package com.altrobyte.altron

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.ContactsContract
import org.json.JSONArray
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService
import java.net.HttpURLConnection
import java.net.URL

/** Jarvis, the founder's assistant, on the phone, all of it in one place (named Jarvis on 25 Oct 2026; the learners'
 *  trainer stays Altron).
 *
 *  Listening: Vosk, offline, Indian English model in assets/model-en-in. The wake phrase is "hey jarvis": both words,
 *  each at confidence 0.8 or more. "jarvis" is a real word in the model, which "altron" never was; alone it also woke on
 *  "the service" and "Travis" in tests, so the two-word phrase is used (only "hey Travis" still matched).
 *
 *  Talking: on a wake the microphone is let go and a thin glowing strip appears along the top of the screen, over any
 *  app (a system overlay, so it stays when the founder moves between apps). Under the strip, out of sight, one WebView
 *  runs Altron's live voice page in founder mode. Only one: a second wake while talking does nothing. When the page
 *  rests (5 s of quiet) or the strip is tapped, the WebView is destroyed (the voice and its bill stop with it) and
 *  listening starts again.
 *
 *  Off: the × on the strip, Stop in the notification, or swiping the app away ends everything: no listening, no voice. */
class WakeService : Service(), RecognitionListener {
    companion object {
        const val ACTION_TALK = "com.altrobyte.altron.TALK"
        const val ACTION_STOP = "com.altrobyte.altron.STOP"
        private const val CHANNEL = "altron_listening"
        private const val NOTE_ID = 7
        private const val GRAMMAR = "[\"hey jarvis\", \"[unk]\"]"
        private const val MIN_CONF = 0.8
        private const val PAGE = "https://altrobytelab.com/live/v2/index.html?founder=1&lang=hi&compact=1&autostart=1"
        @Volatile var running = false
    }

    private val main = Handler(Looper.getMainLooper())
    private var model: Model? = null
    private var speech: SpeechService? = null
    private var strip: FrameLayout? = null
    private var glow: GlowView? = null
    private var web: WebView? = null
    private var talkWhenReady = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        goForeground()
        StorageService.unpack(this, "model-en-in", "model",
            { m -> model = m; if (talkWhenReady) talk() else listen() },
            { e -> Log.w("Altron", "wake model not ready: ${e.message}") })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("key")?.let { k ->
            getSharedPreferences("altron", MODE_PRIVATE).edit()
                .putString("key", k).putString("api", intent.getStringExtra("api") ?: "").apply()
        }
        when (intent?.action) {
            ACTION_STOP -> { off(); return START_NOT_STICKY }
            ACTION_TALK -> if (model == null) talkWhenReady = true else talk()
        }
        return START_STICKY
    }

    /** Swiping the app away is the founder saying "off". */
    override fun onTaskRemoved(rootIntent: Intent?) {
        off()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        quiet()
        endTalk()
        model?.close()
        super.onDestroy()
    }

    private fun off() {
        endTalk()
        quiet()
        stopForeground(true)
        stopSelf()
    }

    // ── listening ──

    private fun listen() {
        val m = model ?: return
        if (speech != null || web != null) return
        try {
            val r = Recognizer(m, 16000.0f, GRAMMAR).apply { setWords(true) }
            speech = SpeechService(r, 16000.0f).also { it.startListening(this) }
        } catch (e: Exception) {
            // The voice page that just closed can hold the microphone a moment longer: try again shortly.
            Log.w("Altron", "could not listen yet: ${e.message}")
            quiet()
            main.postDelayed({ listen() }, 1500)
        }
    }

    private fun quiet() {
        speech?.stop()
        speech?.shutdown()
        speech = null
    }

    private fun heard(json: String?) {
        val words = try { JSONObject(json ?: "{}").optJSONArray("result") } catch (e: Exception) { null } ?: return
        for (i in 0 until words.length() - 1) {
            val a = words.getJSONObject(i)
            val b = words.getJSONObject(i + 1)
            if (a.optString("word") == "hey" && b.optString("word") == "jarvis" &&
                a.optDouble("conf") >= MIN_CONF && b.optDouble("conf") >= MIN_CONF) {
                main.post { talk() }
                return
            }
        }
    }

    override fun onResult(hypothesis: String?) = heard(hypothesis)
    override fun onFinalResult(hypothesis: String?) = heard(hypothesis)
    override fun onPartialResult(hypothesis: String?) {}
    override fun onError(exception: Exception?) { quiet(); main.postDelayed({ listen() }, 1500) }
    override fun onTimeout() { quiet(); listen() }

    // ── talking ──

    private fun talk() {
        talkWhenReady = false
        if (web != null) return                    // already talking: one voice only
        quiet()                                    // the voice page needs the microphone now
        showStrip()
        val prefs = getSharedPreferences("altron", MODE_PRIVATE)
        val key = prefs.getString("key", "") ?: ""
        val api = prefs.getString("api", "") ?: ""
        Thread {
            val token = try {
                val c = URL("$api/founder/key-login").openConnection() as HttpURLConnection
                c.requestMethod = "POST"
                c.setRequestProperty("X-Founder-Key", key)
                c.connectTimeout = 15000; c.readTimeout = 15000
                if (c.responseCode == 200) JSONObject(c.inputStream.bufferedReader().readText()).optString("token") else null
            } catch (e: Exception) { null }
            main.post {
                if (strip == null) return@post     // closed meanwhile
                if (token.isNullOrEmpty()) { glow?.problem = true; main.postDelayed({ endTalk(); listen() }, 4000); return@post }
                openVoice(token)
            }
        }.start()
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun openVoice(token: String) {
        val box = strip ?: return
        val w = WebView(this)
        w.settings.javaScriptEnabled = true
        w.settings.domStorageEnabled = true
        w.settings.mediaPlaybackRequiresUserGesture = false
        w.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) = request.grant(request.resources)
        }
        w.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(s: String) {
                val m = try { JSONObject(s) } catch (e: Exception) { return }
                if (m.optString("type") != "state") return
                val st = m.optString("state")
                main.post {
                    if (st == "paused" || st == "error" || st == "out_of_minutes") { endTalk(); main.postDelayed({ listen() }, 800) }
                    else glow?.speaking = st == "talk"
                }
            }

            /** Altron asked to phone someone: a number, or a name from the contacts. Answers what happened, for Altron
             *  to say. One match calls at once; several come back as names for Altron to ask which. */
            @JavascriptInterface
            fun call(name: String, phone: String): String = placeCall(name.trim(), phone.trim())
        }, "AltronHost")
        w.alpha = 0.01f                            // the voice page runs out of sight, under the light
        box.addView(w, 0, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        w.loadUrl("$PAGE#t=${Uri.encode(token)}")
        web = w
    }

    private fun placeCall(name: String, phone: String): String {
        if (checkSelfPermission(android.Manifest.permission.CALL_PHONE) != android.content.pm.PackageManager.PERMISSION_GRANTED)
            return JSONObject().put("error", "Calls are not allowed for Altron yet. Open the Altron app once to allow them.").toString()
        var number = phone.filter { it.isDigit() || it == '+' }
        var who = name
        if (number.length < 6) {
            if (name.isEmpty()) return JSONObject().put("error", "Say whom to call.").toString()
            if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != android.content.pm.PackageManager.PERMISSION_GRANTED)
                return JSONObject().put("error", "Altron cannot read the contacts yet. Open the Altron app once to allow it.").toString()
            val found = linkedMapOf<String, String>()          // name -> first number
            contentResolver.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?", arrayOf("%$name%"),
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC")?.use { c ->
                while (c.moveToNext() && found.size < 8) {
                    val n = c.getString(0) ?: continue
                    if (!found.containsKey(n)) found[n] = c.getString(1) ?: ""
                }
            }
            val exact = found.keys.firstOrNull { it.equals(name, ignoreCase = true) }
            when {
                found.isEmpty() -> return JSONObject().put("found", 0).put("say", "No contact named $name.").toString()
                exact == null && found.size > 1 -> return JSONObject().put("found", found.size)
                    .put("ask_which", JSONArray(found.keys.take(5))).toString()
            }
            who = exact ?: found.keys.first()
            number = found[who]!!.filter { it.isDigit() || it == '+' }
        }
        main.post {
            endTalk()                               // the call needs the microphone; listening comes back after
            startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            main.postDelayed({ listen() }, 3000)
        }
        return JSONObject().put("calling", who.ifEmpty { number }).toString()
    }

    private fun endTalk() {
        web?.let { it.loadUrl("about:blank"); it.destroy() }
        web = null
        strip?.let { try { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it) } catch (_: Exception) {} }
        strip = null
        glow = null
    }

    // ── the strip ──

    private fun showStrip() {
        if (strip != null) return
        val d = resources.displayMetrics.density
        val box = FrameLayout(this)
        // Over the voice page (added under everything later): a tap on the strip ends the talk; listening goes on.
        box.addView(View(this).apply { setOnClickListener { endTalk(); listen() } },
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        val g = GlowView(this)
        box.addView(g, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, (14 * d).toInt(), Gravity.TOP))
        val close = TextView(this).apply {
            text = "✕"; setTextColor(Color.WHITE); textSize = 13f; gravity = Gravity.CENTER
            setBackgroundColor(Color.argb(150, 15, 37, 48))
            setOnClickListener { off() }
        }
        box.addView(close, FrameLayout.LayoutParams((30 * d).toInt(), (24 * d).toInt(), Gravity.TOP or Gravity.END).apply {
            topMargin = (6 * d).toInt(); rightMargin = (8 * d).toInt()
        })
        val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                   else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val lp = WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, (34 * d).toInt(), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply { gravity = Gravity.TOP }
        try {
            (getSystemService(WINDOW_SERVICE) as WindowManager).addView(box, lp)
            strip = box; glow = g
        } catch (e: Exception) {
            Log.w("Altron", "no strip (display over other apps not allowed?): ${e.message}")
        }
    }

    private fun goForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Jarvis listening", NotificationManager.IMPORTANCE_LOW))
        }
        val talkNow = PendingIntent.getService(this, 0, Intent(this, WakeService::class.java).setAction(ACTION_TALK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, WakeService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        val note = b.setContentTitle("Jarvis is listening")
            .setContentText("Say \"Hey Jarvis\". Stop turns it off completely.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(talkNow)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 30) startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        else startForeground(NOTE_ID, note)
    }
}
