package com.altrobyte.industrial

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Altrobyte Industrial on a plant's tablet. The screen stays on while a worker trains, and the team can pin the app to the
 *  screen (Android's screen pinning) so a worker cannot leave it: one channel, industrial/kiosk: lock() / unlock(). */
class IndustrialActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "industrial/kiosk").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "lock" -> { startLockTask(); result.success(true) }
                    "unlock" -> { stopLockTask(); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }
}
