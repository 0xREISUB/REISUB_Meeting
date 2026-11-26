package xyz.reisub.meeting

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var meetingFullscreen = false
    private var links: MethodChannel? = null

    /** Invite link the activity was started with, handed to Dart once. */
    private var launchLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchLink = inviteLink(intent)
        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reisub_meeting/links")
            .apply {
                setMethodCallHandler { call, result ->
                    if (call.method == "getInitialLink") {
                        result.success(launchLink)
                        launchLink = null
                    } else {
                        result.notImplemented()
                    }
                }
            }
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
                        startForegroundService(intent)
                    } catch (error: Exception) {
                        ScreenShareService.onReady = null
                        result.error("screen_share_service", error.message, null)
                    }
                } else if (call.method == "stopScreenShareService") {
                    stopService(Intent(this, ScreenShareService::class.java))
                    result.success(null)
                } else if (call.method == "startMeetingService") {
                    try {
                        val intent = Intent(this, MeetingService::class.java)
                            .putExtra("channelName", call.argument<String>("channelName"))
                            .putExtra("title", call.argument<String>("title"))
                            .putExtra("body", call.argument<String>("body"))
                        startForegroundService(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("meeting_service", error.message, null)
                    }
                } else if (call.method == "stopMeetingService") {
                    stopService(Intent(this, MeetingService::class.java))
                    result.success(null)
                } else if (call.method == "setKeepScreenOn") {
                    // No screen timeout while a meeting is on screen.
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                } else if (call.method == "moveToBackground") {
                    // Back in a meeting leaves the app running, like Home.
                    result.success(moveTaskToBack(true))
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Invites opened while the app is running (launchMode is singleTop). */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        inviteLink(intent)?.let { links?.invokeMethod("onLink", it) }
    }

    private fun inviteLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val link = intent.data ?: return null
        return withInviteServer(link).toString()
    }

    /**
     * Invite links on the web host (e.g. https://meeting.example/j/<code>) stand
     * for the meeting server users enter in the app, which may be another host
     * (e.g. api.meeting.example). Without this the app would offer to switch
     * servers on every invite.
     */
    private fun withInviteServer(link: Uri): Uri {
        if (link.scheme != "https" || link.getQueryParameter("server") != null) return link
        val settings = packageManager
            .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            .metaData ?: return link
        val host = settings.getString("xyz.reisub.meeting.INVITE_HOST")
        val server = settings.getString("xyz.reisub.meeting.INVITE_SERVER")
        if (server.isNullOrBlank() || !link.host.equals(host, ignoreCase = true)) return link
        return link.buildUpon().appendQueryParameter("server", server).build()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && meetingFullscreen) applyMeetingFullscreen()
    }

    /** Hides the system bars for a meeting, on every Android version. */
    private fun applyMeetingFullscreen() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (meetingFullscreen) {
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        } else {
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }
}
