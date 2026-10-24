package com.altrobyte.altron

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The Altron strip: a see-through Flutter screen (the strip is drawn by Dart, lib/founder_main.dart) that opens over any
 *  app when WakeService hears "Altron". One channel, altron/native:
 *    setup        asks once for what a wake needs (notifications, drawing over other apps, no battery limits), starts listening
 *    listening    whether WakeService is on
 *    rest         the talk is over: listening again, and the strip steps aside
 *    stop         listening off
 *  and tells Dart "woke" when a wake or the launcher brings it back. */
class AltronActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    /** Altron is a thin glowing strip along the top of the screen, nothing more: the window is only that tall, and a
     *  touch anywhere else goes to the app underneath. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setGravity(Gravity.TOP)
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, (40 * resources.displayMetrics.density).toInt())
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
    }

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
        channel?.invokeMethod("woke", null)        // a wake, or the founder opening the app: the strip comes back
    }

    private fun setup() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 51)
        }
        // A wake opens the strip over other apps: Android allows that only to an app that may draw over them.
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
