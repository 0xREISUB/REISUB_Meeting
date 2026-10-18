package com.example.v_meeting

import android.content.Intent
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var meetingFullscreen = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reisub_meeting/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "setFullscreen") {
                    meetingFullscreen = call.arguments == true
                    applyMeetingFullscreen()
                    result.success(null)
                } else if (call.method == "startScreenShareService") {
                    ScreenShareService.onReady = { error ->
                        if (error == null) result.success(null)
                        else result.error("screen_share_service", error.message, null)
                    }
                    try {
                        val intent = Intent(this, ScreenShareService::class.java)
                            .putExtra("channelName", call.argument<String>("channelName"))
                            .putExtra("title", call.argument<String>("title"))
                            .putExtra("body", call.argument<String>("body"))
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                    } catch (error: Exception) {
                        ScreenShareService.onReady = null
                        result.error("screen_share_service", error.message, null)
                    }
                } else if (call.method == "stopScreenShareService") {
                    stopService(Intent(this, ScreenShareService::class.java))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && meetingFullscreen) applyMeetingFullscreen()
    }

    @Suppress("DEPRECATION")
    private fun applyMeetingFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                if (meetingFullscreen) {
                    controller.systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    controller.hide(WindowInsets.Type.systemBars())
                } else {
                    controller.show(WindowInsets.Type.systemBars())
                }
            }
        } else {
            window.decorView.systemUiVisibility = if (meetingFullscreen) {
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            } else {
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            }
        }
    }
}
