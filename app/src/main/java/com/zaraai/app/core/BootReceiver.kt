package com.zaraai.app.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.zaraai.app.voice.VoiceService

/**
 * বুট/আপডেটের পর wake-listener রিআর্ম — শুধু ব্যবহারকারী সেটিংসে চালু রাখলে।
 * কোনো silent/স্বয়ংক্রিয় মাইক ক্যাপচার নেই; foreground notification দৃশ্যমান থাকে।
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in setOf(
                Intent.ACTION_BOOT_COMPLETED, "android.intent.action.QUICKBOOT_POWERON",
                Intent.ACTION_MY_PACKAGE_REPLACED
            )
        ) return

        val enabled = context.getSharedPreferences("zara_boot", Context.MODE_PRIVATE)
            .getBoolean("rearm", false)
        if (!enabled) return

        runCatching {
            val i = Intent(context, VoiceService::class.java).setAction(VoiceService.ACTION_START)
            context.startForegroundService(i)
        }
    }
}
