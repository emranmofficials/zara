package com.zaraai.app.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Maya-র SocialAlarmReceiver-এর নিজস্ব সমতুল্য — পোস্টের আগে সবসময় অনুমতি চায়। */
class SocialAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = intent.getStringExtra("text") ?: "পোস্টের কথা মনে পড়ল"
        ReminderReceiver.show(context, "পোস্ট প্রস্তুত: $text — চালাতে হলে ZaRa-তে বলো।")
    }
}
