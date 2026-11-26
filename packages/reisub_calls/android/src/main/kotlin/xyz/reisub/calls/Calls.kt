package xyz.reisub.calls

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/** A call that rings, as Dart described it. */
data class IncomingCall(
    val id: String,
    val roomId: String,
    val caller: String,
    val title: String,
    val kind: String,
    val targetId: String,
    val secret: String,
    val server: String,
    val endsAt: Long,
    val labels: Map<String, String>,
) {
    fun label(key: String) = labels[key] ?: ""

    fun toMap(action: String) = mapOf(
        "action" to action,
        "id" to id,
        "roomId" to roomId,
        "kind" to kind,
        "targetId" to targetId,
        "title" to title,
    )

    companion object {
        fun from(args: Map<*, *>): IncomingCall? {
            val id = args["id"] as? String ?: return null
            val labels = mutableMapOf<String, String>()
            for (key in listOf("incoming", "answer", "decline", "channel", "missedChannel", "missed")) {
                (args[key] as? String)?.let { labels[key] = it }
            }
            return IncomingCall(
                id = id,
                roomId = args["roomId"] as? String ?: "",
                caller = args["caller"] as? String ?: "",
                title = args["title"] as? String ?: "",
                kind = args["kind"] as? String ?: "",
                targetId = args["targetId"] as? String ?: "",
                secret = args["secret"] as? String ?: "",
                server = args["server"] as? String ?: "",
                endsAt = (args["endsAt"] as? Number)?.toLong() ?: (System.currentTimeMillis() + 45_000),
                labels = labels,
            )
        }
    }
}

/**
 * Rings calls: the phone's own ringtone and vibration, as its ringer mode
 * and Do Not Disturb allow; a notification with Answer and Decline, full
 * screen on the lock screen. Through Telecom when it can, so a volume key
 * silences it and a call on the phone is not disturbed.
 */
object Calls {
    private const val TAG = "ReisubCalls"
    private const val CHANNEL = "incoming_calls"
    private const val MISSED_CHANNEL = "missed_calls"
    const val EXTRA_CALL_ID = "xyz.reisub.calls.CALL_ID"
    const val ACTION_ANSWER = "xyz.reisub.calls.ANSWER"
    const val ACTION_DECLINE = "xyz.reisub.calls.DECLINE"

    private val main = Handler(Looper.getMainLooper())
    val calls = mutableMapOf<String, IncomingCall>()
    private val connections = mutableMapOf<String, CallConnection>()
    private val timeouts = mutableMapOf<String, Runnable>()
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var ringingId: String? = null

    /** An answer or decline Dart has not taken yet. */
    var pendingAction: Map<String, String>? = null

    /** Tells the app's Dart side an action waits; set by the plugin. */
    var onAction: (() -> Unit)? = null

    /** Call screens to close when their call ends. */
    val screens = mutableMapOf<String, () -> Unit>()

    fun show(context: Context, call: IncomingCall) {
        val app = context.applicationContext
        if (calls.containsKey(call.id)) return
        calls[call.id] = call
        val left = call.endsAt - System.currentTimeMillis()
        if (left <= 0) {
            calls.remove(call.id)
            return
        }
        val timeout = Runnable { end(app, call.id, missed = true, missedText = null, labels = call.labels) }
        timeouts[call.id] = timeout
        main.postDelayed(timeout, left + 5_000)
        if (!ringThroughTelecom(app, call)) ring(app, call.id)
    }

    // -- Telecom ------------------------------------------------------------

    fun accountHandle(context: Context) = PhoneAccountHandle(
        ComponentName(context, CallConnectionService::class.java),
        "reisub",
    )

    private fun ringThroughTelecom(context: Context, call: IncomingCall): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val telecom = context.getSystemService(TelecomManager::class.java)
            val handle = accountHandle(context)
            telecom.registerPhoneAccount(
                PhoneAccount.builder(handle, "REISUB Meeting")
                    .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
                    .build(),
            )
            if (!telecom.isIncomingCallPermitted(handle)) {
                // Another call is on: no ringing over it, the notice is
                // enough.
                ring(context, call.id, quiet = true)
                return true
            }
            telecom.addNewIncomingCall(
                handle,
                Bundle().apply { putString(EXTRA_CALL_ID, call.id) },
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "Telecom unavailable, ringing on our own", e)
            false
        }
    }

    fun attach(id: String, connection: CallConnection) {
        connections[id] = connection
    }

    // -- Ringing -------------------------------------------------------------

    /** Shows the call and starts the ringtone and vibration. */
    fun ring(context: Context, id: String, quiet: Boolean = false) {
        val call = calls[id] ?: return
        val manager = context.getSystemService(NotificationManager::class.java)
        createChannels(context, call)
        manager.notify(notificationId(id), buildNotification(context, call))
        if (!quiet) startRinging(context, id)
    }

    private fun startRinging(context: Context, id: String) {
        stopRinging()
        ringingId = id
        val audio = context.getSystemService(AudioManager::class.java)
        val manager = context.getSystemService(NotificationManager::class.java)
        // Do Not Disturb decides for itself; the notice still shows.
        if (manager.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL) return
        val mode = audio.ringerMode
        if (mode == AudioManager.RINGER_MODE_NORMAL) {
            try {
                val uri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                    ?: Settings.System.DEFAULT_RINGTONE_URI
                ringtone = RingtoneManager.getRingtone(context, uri)?.apply {
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
                    play()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not play the ringtone", e)
            }
        }
        if (mode != AudioManager.RINGER_MODE_SILENT) {
            val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(VibratorManager::class.java).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator = v
            val pattern = longArrayOf(0, 800, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(pattern, 0)
            }
        }
    }

    private fun stopRinging() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
        ringingId = null
    }

    /** A volume key: quiet, but the call still shows. */
    fun silence(id: String? = null) {
        if (id == null || id == ringingId) stopRinging()
    }

    // -- Answering -----------------------------------------------------------

    /** The user takes the call: it stops, and the app opens to join. */
    fun answer(context: Context, id: String) {
        val call = calls[id] ?: return
        finish(context, id, DisconnectCause(DisconnectCause.LOCAL))
        pendingAction = call.toMap("answer")
        onAction?.invoke()
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            try {
                context.startActivity(launch)
            } catch (e: Exception) {
                Log.w(TAG, "Could not open the app", e)
            }
        }
    }

    /** The user turns it down; the phone tells the server itself. */
    fun decline(context: Context, id: String) {
        val call = calls[id] ?: return
        finish(context, id, DisconnectCause(DisconnectCause.REJECTED))
        pendingAction = call.toMap("decline")
        onAction?.invoke()
        Thread {
            try {
                val url = URL(call.server.trimEnd('/') + "/calls/" + call.id + "/decline")
                val http = url.openConnection() as HttpURLConnection
                http.requestMethod = "POST"
                http.connectTimeout = 10_000
                http.readTimeout = 10_000
                http.doOutput = true
                http.setRequestProperty("Content-Type", "application/json")
                http.outputStream.use { it.write(JSONObject().put("secret", call.secret).toString().toByteArray()) }
                http.responseCode
                http.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "Could not decline on the server", e)
            }
        }.start()
    }

    /** The call stopped ringing elsewhere: answered there, or over. */
    fun end(context: Context, id: String, missed: Boolean, missedText: String?, labels: Map<String, String>) {
        val call = calls[id]
        finish(
            context,
            id,
            DisconnectCause(if (missed) DisconnectCause.MISSED else DisconnectCause.ANSWERED_ELSEWHERE),
        )
        if (missed && call != null) showMissed(context, call, missedText, labels)
    }

    private fun finish(context: Context, id: String, cause: DisconnectCause) {
        calls.remove(id)
        timeouts.remove(id)?.let { main.removeCallbacks(it) }
        if (ringingId == id) stopRinging()
        context.getSystemService(NotificationManager::class.java).cancel(notificationId(id))
        connections.remove(id)?.let {
            it.setDisconnected(cause)
            it.destroy()
        }
        screens.remove(id)?.invoke()
    }

    // -- Notifications ------------------------------------------------------

    private fun notificationId(id: String) = 0x5ee0000 + (id.hashCode() and 0xffff)

    /** The app's one-colour status bar icon, else its launcher icon. */
    private fun smallIcon(context: Context): Int {
        val icon = context.resources.getIdentifier("ic_notification", "drawable", context.packageName)
        return if (icon != 0) icon else context.applicationInfo.icon
    }

    private fun createChannels(context: Context, call: IncomingCall) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        // The app plays the ringtone itself (so a volume key can stop it):
        // the channel stays silent.
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, call.label("channel").ifEmpty { "Calls" }, NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(MISSED_CHANNEL, call.label("missedChannel").ifEmpty { "Missed calls" }, NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    private fun activityIntent(context: Context, call: IncomingCall, action: String?, code: Int): PendingIntent {
        val intent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra(EXTRA_CALL_ID, call.id)
            if (action != null) this.action = action
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
        }
        return PendingIntent.getActivity(
            context,
            notificationId(call.id) + code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun declineIntent(context: Context, call: IncomingCall): PendingIntent {
        val intent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_DECLINE
            putExtra(EXTRA_CALL_ID, call.id)
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId(call.id) + 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildNotification(context: Context, call: IncomingCall): Notification {
        val fullScreen = activityIntent(context, call, null, 0)
        val answer = activityIntent(context, call, ACTION_ANSWER, 1)
        val decline = declineIntent(context, call)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_MAX)
        }
        builder
            .setSmallIcon(smallIcon(context))
            .setContentTitle(call.title)
            .setContentText(call.label("incoming"))
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreen, true)
            .setContentIntent(fullScreen)
            .setWhen(System.currentTimeMillis())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val person = Person.Builder().setName(call.title).setImportant(true).build()
            builder.setStyle(Notification.CallStyle.forIncomingCall(person, decline, answer))
        } else {
            builder.addAction(Notification.Action.Builder(null, call.label("decline"), decline).build())
            builder.addAction(Notification.Action.Builder(null, call.label("answer"), answer).build())
        }
        return builder.build()
    }

    private fun showMissed(context: Context, call: IncomingCall, text: String?, labels: Map<String, String>) {
        val merged = call.copy(labels = call.labels + labels)
        createChannels(context, merged)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, notificationId(call.id) + 3, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, MISSED_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(smallIcon(context))
            .setContentTitle(merged.label("missed"))
            .setContentText(text ?: call.title)
            .setCategory(Notification.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
        if (open != null) builder.setContentIntent(open)
        context.getSystemService(NotificationManager::class.java)
            .notify(notificationId(call.id) + 1, builder.build())
    }

    fun canUseFullScreen(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    }

    fun openFullScreenSettings(context: Context) {
        if (Build.VERSION.SDK_INT < 34) return
        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
            .setData(Uri.parse("package:" + context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun isLocked(context: Context) =
        context.getSystemService(KeyguardManager::class.java).isKeyguardLocked
}
