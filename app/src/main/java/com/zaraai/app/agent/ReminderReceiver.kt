package com.zaraai.app.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** রিমাইন্ডার নোটিফিকেশন — সিস্টেম consent/visibility মেনে কাজ করে। */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: "ZaRa রিমাইন্ডার"
        show(context, text)
    }

    companion object {
        fun show(context: Context, text: String) {
            val nm = NotificationManagerCompat.from(context)
            val n = NotificationCompat.Builder(context, "zara_voice")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle("ZaRa রিমাইন্ডার")
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()
            runCatching { nm.notify(System.currentTimeMillis().toInt(), n) }
        }
    }
}
