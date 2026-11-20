package com.zaraai.app.agent

import org.json.JSONObject
import java.util.ArrayDeque

/**
 * স্থানীয় নীতি-রক্ষক — কোনো টুল চালানোর আগে কড়া যাচাই।
 * server-pushed কোড নেই; শুধু এই fixed নীতি।
 */
object Guardian {
    private const val MAX_CALLS_PER_MINUTE = 12
    private const val PRIVILEGED_COOLDOWN_MS = 2_000L
    private val calls = ArrayDeque<Long>()
    private val lastPrivileged = mutableMapOf<String, Long>()

    private val SECRET_KEYS = setOf(
        "pin", "otp", "password", "passwd", "card", "cvv", "secret", "token", "api_key"
    )
    private val SECRET_VALUE = Regex("(?i)\\b(\\d{4,6}|[a-z0-9]{12,})\\b")

    /** null মানে অনুমোদিত; নাহলে বাতিলের কারণ। */
    fun check(tool: String, args: JSONObject, privileged: Boolean): String? {
        val now = System.currentTimeMillis()
        synchronized(this) {
            while (calls.isNotEmpty() && now - calls.first() > 60_000L) calls.removeFirst()
            if (calls.size >= MAX_CALLS_PER_MINUTE)
                return "এক মিনিটে অনেক বেশি কাজ — থামো, পরে চেষ্টা করো।"
            calls.addLast(now)

            if (privileged) {
                val last = lastPrivileged[tool] ?: 0L
                if (now - last < PRIVILEGED_COOLDOWN_MS)
                    return "$tool আগে চালানো হয়েছে — একটু অপেক্ষা করো।"
                lastPrivileged[tool] = now
            }
        }
        val keys = args.keys().asSequence().map { it.lowercase() }.toSet()
        if (keys.any { it in SECRET_KEYS })
            return "PIN/OTP/password-এর মতো কিছু চাইনি — তা নিয়ে কাজ করব না।"
        val values = args.keys().asSequence().mapNotNull { args.optString(it, null) }
        if (values.any { it != null && SECRET_VALUE.containsMatchIn(it) })
            return "সংবেদনশীল সংখ্যা দেখছি — বাতিল করলাম।"
        return null
    }

    /** লগ/ইতিহাসে গোপন তথ্য না যায়। */
    fun redact(text: String): String = SECRET_VALUE.replace(text, "[রেড্যাক্টেড]")
}
