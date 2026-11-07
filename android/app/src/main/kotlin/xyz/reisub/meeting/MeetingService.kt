package xyz.reisub.meeting

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Runs while the user is in a meeting, so Android keeps the app alive in the
 * background and lets it keep using the microphone and playing the meeting's
 * audio. Stops when the meeting ends or the app is swiped away.
 */
class MeetingService : Service() {
    companion object {
        private const val CHANNEL = "meeting_in_progress"
        private const val NOTIFICATION_ID = 4822
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel(
                    CHANNEL, intent?.getStringExtra("channelName") ?: "Meeting",
                    NotificationManager.IMPORTANCE_LOW
                ))
            }
            val launch = PendingIntent.getActivity(this, 0,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL)
                else @Suppress("DEPRECATION") Notification.Builder(this)
            val notification = builder.setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle(intent?.getStringExtra("title") ?: "Meeting in progress")
                .setContentText(intent?.getStringExtra("body") ?: "Tap to return to the meeting.")
                .setContentIntent(launch).setOngoing(true).build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(NOTIFICATION_ID, notification, serviceType())
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            // Without the service the meeting still works in the foreground.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    /**
     * The microphone type keeps capture working in the background; Android
     * only accepts it with the microphone permission granted. Without it the
     * service still keeps the meeting's audio playing.
     */
    private fun serviceType(): Int {
        val microphone = checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        return if (microphone) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf() }
}
