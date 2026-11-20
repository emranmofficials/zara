package com.zaraai.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.UUID

/**
 * Reads notification reply actions for supported chat apps and exposes them to
 * Flutter through [ReplyCache]. Uses only public NotificationListenerService
 * and RemoteInput APIs - never accessibility click simulation.
 */
class ZaraNotificationListener : NotificationListenerService() {
    companion object {
        /** Extend this list to support more chat apps. */
        private val SUPPORTED_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "com.google.android.apps.messaging",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        if (sbn.packageName !in SUPPORTED_PACKAGES) return

        try {
            val chat = notification.extras
                .getCharSequence(Notification.EXTRA_TITLE)?.toString()
                ?.takeIf { it.isNotBlank() } ?: return

            val actions = notification.actions ?: return
            for (action in actions) {
                val inputs = action.remoteInputs
                if (!inputs.isNullOrEmpty() && inputs.any { it.allowFreeFormInput }) {
                    val token = UUID.randomUUID().toString()
                    ReplyCache.actions[token] = action
                    ReplyCache.queue.add(
                        ReplyCache.Target(
                            token,
                            chat,
                            sbn.packageName,
                            System.currentTimeMillis(),
                        )
                    )
                    break
                }
            }
        } catch (_: Exception) {
            // A malformed notification must never take the listener service down.
        }
    }
}
