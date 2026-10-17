package com.altrobyte.caller

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.provider.Settings
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** The Flutter screen, plus the one channel (altrobyte.caller/native) the Dart side uses for everything that needs the
 *  phone: see lib/caller/caller_native.dart. */
class CallerActivity : FlutterActivity() {
    companion object {
        @Volatile var live: CallerActivity? = null
        private const val ASK_PERMISSION = 41
        private const val ASK_SPEECH = 42
    }

    private var channel: MethodChannel? = null
    private var dartReady = false
    private var permissionResult: MethodChannel.Result? = null
    private var speechResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "altrobyte.caller/native").also {
            it.setMethodCallHandler(::onCall)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        live = this
        takeIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        takeIntent(intent)
        deliverPending()
    }

    override fun onDestroy() {
        if (live === this) live = null
        super.onDestroy()
    }

    private fun takeIntent(i: Intent?) {
        i?.getStringExtra("open_phone")?.let { CallerStore(this).setPendingOpen(it) }
    }

    /** Hands the Dart side what happened while it was not looking. Only once it has said it is listening, or the event
     *  would be dropped. */
    fun deliverPending() {
        val ch = channel ?: return
        if (!dartReady) return
        val store = CallerStore(this)
        store.takePendingOpen()?.let { ch.invokeMethod("openLead", it) }
        store.takePendingCall()?.let { ch.invokeMethod("callEnded", jsonToMap(JSONObject(it))) }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "placeCall" -> result.success(placeCall(call.argument<String>("phone") ?: ""))
                "permissions" -> result.success(permissions())
                "requestPermission" -> requestPermission(call.argument<String>("name") ?: "", result)
                "deliverPending" -> {
                    dartReady = true
                    deliverPending()
                    result.success(null)
                }
                "schedule" -> {
                    Reminders.replaceAll(this, call.argument<String>("reminders") ?: "[]")
                    result.success(null)
                }
                "setDirectory" -> {
                    CallerStore(this).setDirectory(
                        call.argument<String>("directory") ?: "{}",
                        call.argument<String>("token") ?: "",
                        call.argument<String>("base_url") ?: "")
                    result.success(null)
                }
                "speechToText" -> speech(result)
                "recentCalls" -> result.success(recentCalls(call.argument<Int>("limit") ?: 300))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native", e.message, null)
        }
    }

    private fun granted(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun placeCall(phone: String): Boolean {
        val digits = phone.filter { it.isDigit() || it == '+' }
        if (digits.isEmpty()) return false
        CallerStore(this).expect(digits)
        val action = if (granted(Manifest.permission.CALL_PHONE)) Intent.ACTION_CALL else Intent.ACTION_DIAL
        startActivity(Intent(action, Uri.parse("tel:$digits")))
        return true
    }

    /** The phone's own call history, newest first: number, the name saved in contacts, direction, length, when. Read
     *  on the phone only; the app sends a call to the CRM only when the caller logs it. */
    private fun recentCalls(limit: Int): List<Map<String, Any?>>? {
        if (!granted(Manifest.permission.READ_CALL_LOG)) return null
        val cols = arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME, CallLog.Calls.TYPE, CallLog.Calls.DURATION,
            CallLog.Calls.DATE)
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(CallLog.Calls.CONTENT_URI, cols, null, null, "${CallLog.Calls.DATE} DESC")?.use { c ->
            while (c.moveToNext() && out.size < limit) {
                val type = when (c.getInt(2)) {
                    CallLog.Calls.OUTGOING_TYPE -> "out"
                    CallLog.Calls.INCOMING_TYPE -> "in"
                    CallLog.Calls.REJECTED_TYPE -> "rejected"
                    CallLog.Calls.BLOCKED_TYPE -> "blocked"
                    else -> "missed"
                }
                out.add(mapOf("phone" to (c.getString(0) ?: ""), "name" to (c.getString(1) ?: ""), "type" to type,
                    "duration_s" to c.getLong(3), "started_at_ms" to c.getLong(4)))
            }
        }
        return out
    }

    private fun permissions(): Map<String, Boolean> {
        val nm = getSystemService(NotificationManager::class.java)
        val am = getSystemService(AlarmManager::class.java)
        return mapOf(
            "call_phone" to granted(Manifest.permission.CALL_PHONE),
            "phone_state" to granted(Manifest.permission.READ_PHONE_STATE),
            "call_log" to granted(Manifest.permission.READ_CALL_LOG),
            "notifications" to nm.areNotificationsEnabled(),
            "overlay" to Settings.canDrawOverlays(this),
            "exact_alarm" to (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()),
        )
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val perm = when (name) {
            "call_phone" -> Manifest.permission.CALL_PHONE
            "phone_state" -> Manifest.permission.READ_PHONE_STATE
            "call_log" -> Manifest.permission.READ_CALL_LOG
            "notifications" -> if (Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
            "overlay" -> {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                return result.success(false)
            }
            "exact_alarm" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                }
                return result.success(false)
            }
            else -> return result.success(false)
        }
        if (perm == null || granted(perm)) return result.success(true)
        // Asked before and refused for good: Android will not show the prompt again, so open the app's settings page.
        if (wasAsked(perm) && !shouldShowRequestPermissionRationale(perm)) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
            return result.success(false)
        }
        markAsked(perm)
        permissionResult?.success(false)
        permissionResult = result
        requestPermissions(arrayOf(perm), ASK_PERMISSION)
    }

    private fun wasAsked(p: String) = getSharedPreferences("altrobyte_caller", MODE_PRIVATE).getBoolean("asked_$p", false)
    private fun markAsked(p: String) = getSharedPreferences("altrobyte_caller", MODE_PRIVATE).edit().putBoolean("asked_$p", true).apply()

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ASK_PERMISSION) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    private fun speech(result: MethodChannel.Result) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Say the note")
        }
        if (intent.resolveActivity(packageManager) == null) return result.success(null)
        speechResult?.success(null)
        speechResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, ASK_SPEECH)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ASK_SPEECH) {
            speechResult?.success(data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull())
            speechResult = null
        }
    }
}

fun jsonToMap(o: JSONObject): Map<String, Any?> = o.keys().asSequence().associateWith { k ->
    when (val v = o.get(k)) {
        JSONObject.NULL -> null
        else -> v
    }
}
