package com.altrobyte.altron

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService

/** Listens for "Altron" all the time, on the phone, offline (Vosk, Indian English model in assets/model-en-in).
 *
 *  The model has no word "altron", but hears it as "al tron"; the grammar holds only that and [unk], and a wake needs
 *  both words at confidence 0.8 or more (tested on speech samples: every "Altron" woke it, "electron", "control",
 *  "call Ravi" did not). On a wake the microphone is let go at once, because Altron's own voice page needs it, and the
 *  card opens over whatever is on screen. ACTION_RESUME starts listening again when the card goes away. */
class WakeService : Service(), RecognitionListener {
    companion object {
        const val ACTION_RESUME = "com.altrobyte.altron.RESUME"
        const val ACTION_STOP = "com.altrobyte.altron.STOP"
        private const val CHANNEL = "altron_listening"
        private const val NOTE_ID = 7
        private const val GRAMMAR = "[\"al tron\", \"[unk]\"]"
        private const val MIN_CONF = 0.8
        @Volatile var running = false
    }

    private var model: Model? = null
    private var speech: SpeechService? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        goForeground()
        StorageService.unpack(this, "model-en-in", "model",
            { m -> model = m; listen() },
            { e -> Log.w("Altron", "wake model not ready: ${e.message}"); stopSelf() })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
            ACTION_RESUME -> listen()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        quiet()
        model?.close()
        super.onDestroy()
    }

    private fun listen() {
        val m = model ?: return
        if (speech != null) return
        try {
            val r = Recognizer(m, 16000.0f, GRAMMAR).apply { setWords(true) }
            speech = SpeechService(r, 16000.0f).also { it.startListening(this) }
        } catch (e: Exception) {
            Log.w("Altron", "could not listen: ${e.message}")
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
            if (a.optString("word") == "al" && b.optString("word") == "tron" &&
                a.optDouble("conf") >= MIN_CONF && b.optDouble("conf") >= MIN_CONF) {
                wake()
                return
            }
        }
    }

    private fun wake() {
        quiet()                                   // the voice page needs the microphone now
        startActivity(Intent(this, AltronActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("woke", true)
        })
    }

    override fun onResult(hypothesis: String?) = heard(hypothesis)
    override fun onFinalResult(hypothesis: String?) = heard(hypothesis)
    override fun onPartialResult(hypothesis: String?) {}
    override fun onError(exception: Exception?) { quiet(); listen() }
    override fun onTimeout() { quiet(); listen() }

    private fun goForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Altron listening", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, AltronActivity::class.java).putExtra("woke", true),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, WakeService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        val note = b.setContentTitle("Altron is listening")
            .setContentText("Say \"Altron\" to ask about your leads or your course.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 30) startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        else startForeground(NOTE_ID, note)
    }
}
