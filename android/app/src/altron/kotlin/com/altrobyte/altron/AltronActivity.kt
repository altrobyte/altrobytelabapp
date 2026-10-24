package com.altrobyte.altron

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Opening the app: asks once for what Altron needs, starts it talking (WakeService owns the strip, the voice and the
 *  listening), and steps away. Nothing of Altron lives here, so closing this screen never leaves a second voice behind.
 *  One channel, altron/native:  start(key, api)  ->  "started" | "needs_overlay". */
class AltronActivity : FlutterActivity() {
    private var waitingForOverlay = false
    private var key = ""
    private var api = ""

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "altron/native").setMethodCallHandler { call, result ->
            if (call.method != "start") return@setMethodCallHandler result.notImplemented()
            key = call.argument<String>("key") ?: ""
            api = call.argument<String>("api") ?: ""
            askOnce()
            if (Settings.canDrawOverlays(this)) { go(); result.success("started") }
            else {
                // The strip sits over other apps: Android allows that only to an app that may draw over them.
                waitingForOverlay = true
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                result.success("needs_overlay")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (waitingForOverlay && Settings.canDrawOverlays(this)) { waitingForOverlay = false; go() }
    }

    private fun askOnce() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 51)
        }
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            try { startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))) }
            catch (_: Exception) {}
        }
    }

    private fun go() {
        val i = Intent(this, WakeService::class.java).setAction(WakeService.ACTION_TALK).putExtra("key", key).putExtra("api", api)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        // Android gives a background service the microphone only if it went to the foreground while the app was on
        // screen; stepping away at once left the listening silenced. So this screen waits a moment before it goes.
        window.decorView.postDelayed({ finish() }, 2500)
    }
}
