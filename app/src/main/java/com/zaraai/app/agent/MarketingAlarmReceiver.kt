package com.zaraai.app.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Maya-র MarketingAlarmReceiver-এর নিজস্ব সমতুল্য — শুধু রিমাইন্ডার, স্বয়ংক্রিয় পোস্ট নয়। */
class MarketingAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: "মার্কেটিং টাস্ক"
        ReminderReceiver.show(context, "মার্কেটিং: $text — অনুমতি ছাড়া কিছু পাঠানো হয়নি।")
    }
}
