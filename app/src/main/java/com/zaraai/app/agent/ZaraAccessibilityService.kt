package com.zaraai.app.agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Path
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Maya-র MayaAccessibilityService-র নিজস্ব সমতুল্য। সব অ্যাকশন শুধু তখনই চলে যখন
 * ব্যবহারকারী সরাসরি অনুমতি দেয়; সবসময় দৃশ্যমান notification থাকে। কোনো covert
 * স্ক্রিন ক্যাপচার বা আপলোড নেই।
 */
class ZaraAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var instance: ZaraAccessibilityService? = null
            private set

        private const val CHANNEL = "zara_a11y"
        private const val NOTIF_ID = 3
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "ZaRa অ্যাক্সেসিবিলিটি", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val n = Notification.Builder(this, CHANNEL)
            .setContentTitle("ZaRa অ্যাক্সেসিবিলিটি চালু")
            .setContentText("স্পর্শ/টাইপ শুধু তোমার অনুমতিতেই হবে")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .build()
        startForeground(NOTIF_ID, n)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    fun readText(limit: Int = 2000): String {
        val root = rootInActiveWindow ?: return "স্ক্রিন পড়া যায়নি।"
        val out = StringBuilder()
        collect(root, out, limit)
        return out.toString().ifBlank { "কোনো লেখা পাওয়া গেলো না।" }
    }

    private fun collect(node: AccessibilityNodeInfo?, out: StringBuilder, limit: Int) {
        if (node == null || out.length >= limit) return
        val text = node.text?.toString().orEmpty()
        val desc = node.contentDescription?.toString().orEmpty()
        if (text.isNotBlank()) out.append(text).append('\n')
        else if (desc.isNotBlank()) out.append(desc).append('\n')
        for (i in 0 until node.childCount) collect(node.getChild(i), out, limit)
    }

    fun tapText(target: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = find(root, target) ?: return false
        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    private fun find(node: AccessibilityNodeInfo?, target: String): AccessibilityNodeInfo? {
        if (node == null) return null
        val t = node.text?.toString().orEmpty()
        val d = node.contentDescription?.toString().orEmpty()
        if (t.contains(target, true) || d.contains(target, true)) return node
        for (i in 0 until node.childCount) {
            find(node.getChild(i), target)?.let { return it }
        }
        return null
    }

    fun press(action: Int): Boolean {
        performGlobalAction(action)
        return true
    }

    fun swipe(x1: Float, y1: Float, x2: Float, y2: Float): Boolean {
        if (Build.VERSION.SDK_INT < 24) return false
        val path = Path().apply { moveTo(x1, y1); lineTo(x2, y2) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 250)
        return dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }
}
