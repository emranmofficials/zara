package com.zaraai.app.agent

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * নিজস্ব নোটিফিকেশন পড়ার সার্ভিস — শুধু Android-র NotificationListener permission,
 * ব্যবহারকারী Settings-এ নিজে অন করে নেয়। কোনো covert capture বা আপলোড নেই।
 */
class ZaraNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        val text = n.notification.extras?.getCharSequence("android.text")?.toString().orEmpty()
        if (text.isBlank()) return
        synchronized(recent) {
            recent.add(0, text)
            while (recent.size > 20) recent.removeAt(recent.size - 1)
        }
    }

    companion object {
        private val recent = mutableListOf<String>()
        fun latest(limit: Int = 5): List<String> = synchronized(recent) { recent.take(limit) }
    }
}
