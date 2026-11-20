package com.zaraai.app.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** স্ক্রিন ক্যাপচার চলাকালীন বাধ্যতামূলক দৃশ্যমান ইঙ্গিত — কোনো গোপন ক্যাপচার নয়। */
class ScreenCaptureService : Service() {
    companion object {
        const val ACTION_START = "com.zaraai.app.voice.SCREEN_START"
        const val ACTION_STOP = "com.zaraai.app.voice.SCREEN_STOP"
        private const val CHANNEL = "zara_screen"
        private const val ID = 2
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "ZaRa স্ক্রিন", NotificationManager.IMPORTANCE_LOW)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val n = notification()
                if (Build.VERSION.SDK_INT >= 29)
                    startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
                else startForeground(ID, n)
            }
            ACTION_STOP -> { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
        }
        return START_STICKY
    }

    private fun notification(): Notification =
        Notification.Builder(this, CHANNEL)
            .setContentTitle("ZaRa স্ক্রিন ক্যাপচার")
            .setContentText("তুমি অনুমতি দিয়েছো — শুধু এই ডিভাইসে প্রক্রিয়া হয়")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .build()
}
