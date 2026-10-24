package com.altrobyte.altron

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The Altron card: a see-through Flutter screen (the card is drawn by Dart, lib/founder_main.dart) that opens over any
 *  app when WakeService hears "Altron". One channel, altron/native:
 *    setup        asks once for what a wake needs (notifications, drawing over other apps, no battery limits), starts listening
 *    listening    whether WakeService is on
 *    rest         the talk is over: listening again, and the card steps aside
 *    stop         listening off
 *  and tells Dart "woke" when a wake brings an already open card back. */
class AltronActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "altron/native").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setup" -> { setup(); result.success(WakeService.running) }
                    "listening" -> result.success(WakeService.running)
                    "woke" -> result.success(intent?.getBooleanExtra("woke", false) == true)
                    "rest" -> {
                        startService(Intent(this, WakeService::class.java).setAction(WakeService.ACTION_RESUME))
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    "stop" -> {
                        startService(Intent(this, WakeService::class.java).setAction(WakeService.ACTION_STOP))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("woke", false)) channel?.invokeMethod("woke", null)
    }

    private fun setup() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 51)
        }
        // A wake opens the card over other apps: Android allows that only to an app that may draw over them.
        if (!Settings.canDrawOverlays(this)) {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        }
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            try {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
            } catch (_: Exception) {}
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED && !WakeService.running) {
            val i = Intent(this, WakeService::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        }
    }
}
