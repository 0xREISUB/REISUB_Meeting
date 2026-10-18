package com.example.v_meeting

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** Keeps MediaProjection alive only while the user is sharing their screen. */
class ScreenShareService : Service() {
    companion object {
        var onReady: ((Exception?) -> Unit)? = null
        private const val CHANNEL = "meeting_screen_share"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel(
                    CHANNEL, intent?.getStringExtra("channelName") ?: "Screen sharing", NotificationManager.IMPORTANCE_LOW
                ))
            }
            val launch = PendingIntent.getActivity(this, 0,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL)
                else @Suppress("DEPRECATION") Notification.Builder(this)
            val notification = builder.setSmallIcon(android.R.drawable.ic_menu_camera)
                .setContentTitle(intent?.getStringExtra("title") ?: "Your screen is being shared")
                .setContentText(intent?.getStringExtra("body") ?: "Return to the meeting to stop sharing.")
                .setContentIntent(launch).setOngoing(true).build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(4821, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(4821, notification)
            }
            onReady?.invoke(null)
        } catch (error: Exception) {
            onReady?.invoke(error)
            stopSelf()
        } finally {
            onReady = null
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf() }
}
