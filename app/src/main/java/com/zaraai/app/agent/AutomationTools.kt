package com.zaraai.app.agent

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import com.zaraai.app.data.MemoryStore
import org.json.JSONObject

/**
 * নিজস্ব, fixed অটোমেশন টুল — কোনো server-pushed bundle নয়।
 * প্রতিটি সংবেদনশীল টুলের আগে biometric + এক-বারের consent + Guardian যাচাই।
 */
fun buildAutomationTools(
    context: Context,
    consent: ConsentManager,
    memory: MemoryStore
): List<Tool> = listOf(
    Tool("get_battery", "এই ডিভাইসের ব্যাটারি লেভেল", false) {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        JSONObject().put("level", bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY))
    },
    Tool("set_reminder", "নির্দিষ্ট মিনিট পর বাংলা রিমাইন্ডার দেয়", true) { args ->
        val reason = Guardian.check("set_reminder", args, privileged = true)
        if (reason != null) return@Tool JSONObject().put("error", reason)
        if (!consent.consume("set_reminder"))
            return@Tool JSONObject().put("error", "অনুমতি মেয়াদোত্তীর্ণ — আবার জিজ্ঞেস করো।")

        val minutes = args.optInt("minutes", 5).coerceIn(1, 1440)
        val text = args.optString("text", "রিমাইন্ডার").take(160)
        val intent = Intent(context, ReminderReceiver::class.java).putExtra("text", text)
        val pi = PendingIntent.getBroadcast(
            context, (System.currentTimeMillis() and 0x7fffffff).toInt(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + minutes * 60_000L, pi)
        JSONObject().put("ok", true).put("minutes", minutes).put("text", text)
    },
    Tool("add_note", "স্থানীয় মেমরিতে নোট যোগ করে", true) { args ->
        val reason = Guardian.check("add_note", args, privileged = true)
        if (reason != null) return@Tool JSONObject().put("error", reason)
        if (!consent.consume("add_note"))
            return@Tool JSONObject().put("error", "অনুমতি নেই — নোট যোগ করা হয়নি।")
        val text = args.optString("text", "").take(500)
        if (text.isBlank()) return@Tool JSONObject().put("error", "কিছু লেখো নি।")
        memory.remember(text, "note")
        JSONObject().put("ok", true)
    },
    Tool("recall_notes", "আগের নোট থেকে মিল খুঁজে বের করে", false) { args ->
        val q = args.optString("query", "")
        val hits = memory.recall(q)
        JSONObject().put("results", org.json.JSONArray(hits))
    },
    Tool("remember_fact", "স্থানীয় মেমরিতে তথ্য যোগ করে", true) { args ->
        val reason = Guardian.check("remember_fact", args, privileged = true)
        if (reason != null) return@Tool JSONObject().put("error", reason)
        if (!consent.consume("remember_fact"))
            return@Tool JSONObject().put("error", "অনুমতি নেই — মনে রাখা হয়নি।")
        val text = args.optString("text", "").take(500)
        if (text.isBlank()) return@Tool JSONObject().put("error", "কিছু লেখো নি।")
        memory.rememberFact(text)
        JSONObject().put("ok", true)
    },
    Tool("forget_memory", "স্থানীয় মেমরি থেকে মিল থাকা তথ্য বাদ দেয়", true) { args ->
        val reason = Guardian.check("forget_memory", args, privileged = true)
        if (reason != null) return@Tool JSONObject().put("error", reason)
        if (!consent.consume("forget_memory"))
            return@Tool JSONObject().put("error", "অনুমতি নেই — কিছু বাদ দেওয়া হয়নি।")
        val text = args.optString("text", "")
        JSONObject().put("ok", memory.forgetMemory(text))
    },
    Tool("my_details", "আমার সম্পর্কে নিজস্ব তথ্য দেখায়", false) { _ ->
        JSONObject().put("ok", true).put("details", memory.myDetails())
    },
    Tool("set_my_detail", "আমার সম্পর্কে নিজস্ব তথ্য যোগ করে", true) { args ->
        val reason = Guardian.check("set_my_detail", args, privileged = true)
        if (reason != null) return@Tool JSONObject().put("error", reason)
        if (!consent.consume("set_my_detail"))
            return@Tool JSONObject().put("error", "অনুমতি নেই — তথ্য রাখা হয়নি।")
        val key = args.optString("key", "").take(40)
        val value = args.optString("value", "").take(200)
        if (key.isBlank() || value.isBlank()) return@Tool JSONObject().put("error", "key আর value দাও।")
        memory.setMyDetail(key, value)
        JSONObject().put("ok", true)
    }
)
