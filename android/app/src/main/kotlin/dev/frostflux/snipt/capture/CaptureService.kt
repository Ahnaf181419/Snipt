package dev.frostflux.snipt.capture

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import dev.frostflux.snipt.MainActivity

/**
 * Lane-B capture engine: a long-lived foreground service whose persistent
 * notification gives the user a one-tap "capture clip" action. Tapping it
 * brings [MainActivity] to the foreground (where the clipboard is readable)
 * and triggers a capture.
 *
 * Declared as a `specialUse` foreground service because clipboard management
 * does not map to a standard FGS type; the Play Console Data Safety form must
 * state that captured data never leaves the device.
 */
class CaptureService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startForegroundNotification()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun startForegroundNotification() {
        ensureChannel()

        val captureIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_CAPTURE_NOW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            REQUEST_CAPTURE,
            captureIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("snipt is running")
            .setContentText("Copy something, then tap Capture clip to save it.")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_menu_save, "Capture clip", pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Clipboard capture",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "Keeps snipt ready to save clips." },
            )
        }
    }

    companion object {
        @Volatile
        var isRunning: Boolean = false

        private const val CHANNEL_ID = "snipt_capture"
        private const val NOTIFICATION_ID = 42
        private const val REQUEST_CAPTURE = 1
    }
}
