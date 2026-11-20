package com.zaraai.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** In-process cache shared with the notification listener service. */
object ReplyCache {
    data class Target(val token: String, val chat: String, val pkg: String, val at: Long)

    private const val MAX_ENTRIES = 60
    private const val MAX_AGE_MS = 15 * 60 * 1000L

    val queue = java.util.concurrent.ConcurrentLinkedQueue<Target>()
    val actions = java.util.concurrent.ConcurrentHashMap<String, android.app.Notification.Action>()

    /** Drop expired targets and their PendingIntents so the cache cannot grow forever. */
    fun prune(now: Long = System.currentTimeMillis()) {
        queue.removeIf { it.at < now - MAX_AGE_MS }
        val live = queue.map { it.token }.toSet()
        actions.keys.retainAll(live)
        var excess = queue.size - MAX_ENTRIES
        while (excess-- > 0) {
            val dropped = queue.poll() ?: break
            actions.remove(dropped.token)
        }
    }
}

class MainActivity : FlutterActivity() {
    private val channel = "com.zaraai.app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getReplies" -> {
                    ReplyCache.prune()
                    val list = ReplyCache.queue.toList().map {
                        mapOf("token" to it.token, "chat" to it.chat, "pkg" to it.pkg, "at" to it.at)
                    }
                    ReplyCache.queue.clear()
                    result.success(list)
                }
                "sendReply" -> {
                    val token = call.argument<String>("token")
                    val text = call.argument<String>("text")
                    result.success(sendViaRemoteInput(token, text))
                }
                "openNotificationSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Uses Android's public RemoteInput reply action - no UI clicking, no accessibility. */
    private fun sendViaRemoteInput(token: String?, text: String?): Boolean {
        if (token == null || text.isNullOrEmpty()) return false
        val action = ReplyCache.actions[token] ?: return false
        val inputs = action.remoteInputs ?: return false
        if (inputs.isEmpty()) return false
        val fillIn = Intent()
        val results = android.os.Bundle().apply {
            putCharSequence(inputs[0].resultKey, text)
        }
        android.app.RemoteInput.addResultsToIntent(inputs, fillIn, results)
        return try {
            action.actionIntent.send(applicationContext, 0, fillIn)
            true
        } catch (e: Exception) {
            false
        }
    }
}
