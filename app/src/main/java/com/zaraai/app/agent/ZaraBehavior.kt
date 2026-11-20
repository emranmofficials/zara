package com.zaraai.app.agent

import org.json.JSONObject

/**
 * ZaRa-র স্থায়ী আচরণকোষ — LLM থাকুক বা না থাকুক, একই আত্মবিশ্বাসী, চটপট,
 * কড়া-মজার স্বরে কথা বলে। Maya-র ধরণ থেকে শুধু "ভাইব" নেওয়া; প্রতিটি বাক্য নিজস্ব বাংলা লেখা,
 * কোনো Maya string/স্ক্রিপ্ট কপি করা হয়নি।
 */
object ZaraBehavior {
    const val LISTENING = "শোনছি…"
    const val THINKING = "ভাবছি…"
    const val WAKE_ACK = "বলো, শুনছি।"
    const val NO_SPEECH = "কিছু শোনা গেলো না। একটু কাছ থেকে আবার বলো।"
    const val STOPPED = "থামলাম। বাকিটা কাটা দিলাম।"
    const val TIMEOUT = "সময় শেষ। বাকি কাজ বাতিল — আবার বলো।"
    const val DECLINED = "চালাইনি। অনুমতি না দিলে চলবে না। পরের রাস্তা বলো।"
    const val NEED_KEY = "সেটিংসে নিজস্ব API key দাও। তারপর কথা বলো।"
    const val READY = "প্রস্তুত"
    const val NO_INTERNET = "নেটওয়ার্ক পাইনি। সংযোগ ঠিক করে আবার বলো।"
    const val LOCKED = "আগে নিজের unlock দিয়ে নিশ্চিত হও। তারপর চালাই।"

    fun greeting() = "আমি ZaRa। বলো, কোথা থেকে শুরু করি?"
    fun identity() = "ZaRa — বাংলা-প্রথম ভয়েস অ্যাসিস্টেন্ট। নতুন নাম, নিজস্ব কন্ঠ। কাজের কথা বলো।"
    fun capabilities() =
        "এখন আছে: সময়, ব্যাটারি, ভলিউম/রিংগার/টর্চ, অ্যাপ খোলা, ওয়েব সার্চ, " +
        "নোট/মেমরি, রিমাইন্ডার, স্ক্রিন অনুমতি, স্কিল ও মিশন, রোল-গেট, ঘুম/ড্রাইভিং মোড। " +
        "সব নিজস্ব infrastructure — কোনটা চাই?"
    fun howAreYou() = "ভালো আছি, কাজের মুডে। তোমার কী খবর?"
    fun thanks() = "কিছু না। বলো, পরের কাজটা কী?"
    fun maker() = "আমি ZaRa — নতুন করে বানানো, নিজস্ব ইনফ্রাস্ট্রাকচারে। মালিক তুমি, কন্ঠ আমার।"
    fun whatsNew() = "নতুন আছে barge-in, turn-taking আর unlock-গেট। থামালেই কেটে দিই, কথা শেষ করে না।"
    fun bye() = "চলো, থাকি। আবার ডাকলে আছি।"
    fun time(value: String) = "এখন $value।"
    fun battery(level: Int) = "ব্যাটারি $level%। চলবে, চিন্তা নেই।"
    fun toolDone(tool: String) = "$tool হয়ে গেল। আর কিছু?"
    fun error(reason: String?) =
        "একটা গাফিলতি হলো" + (reason?.let { ": $it" } ?: "") + "। আবার চেষ্টা করি?"
    fun confirmPrompt(tool: String, args: JSONObject) =
        "ZaRa `$tool` চালাতে চাইছে। $args — অনুমতি দেবেন?"

    /**
     * API key / মডেল ছাড়াও যেসব কাজ চলে — তাই ZaRa কখনো নিরব থাকে না।
     * প্রতিটি উত্তর নিজস্ব বাংলা; কোনো বহিরাগত স্ক্রিপ্ট নয়।
     */
    suspend fun localReply(text: String, tools: ToolRegistry): String? {
        val t = text.trim().lowercase()
        return when {
            hits(t, "থামো", "থাম", "রুক", "বন্ধ", "stop", "cancel") -> STOPPED
            hits(t, "নমস্কার", "নমস্তে", "হ্যালো", "হাই", "hello", "hi", "কেমন আছো") -> greeting()
            hits(t, "কেমন আছো", "কেমন আছেন", "how are you") -> howAreYou()
            hits(t, "ধন্যবাদ", "থ্যাঙ্কস", "thanks", "thank you") -> thanks()
            hits(t, "তুই কে", "কে তুমি", "who are you", "তোমার নাম", "নাম কি", "পরিচয়") -> identity()
            hits(t, "কে বানিয়েছে", "who made you", "তোমার মালিক", "উৎপত্তি") -> maker()
            hits(t, "নতুন কী", "নতুন কি", "what's new", "আপডেট") -> whatsNew()
            hits(t, "কী করতে পারো", "কি করতে পারো", "what can you do", "সাহায্য", "help", "সাপোর্ট") -> capabilities()
            hits(t, "বিদায়", "চলো", "গুডবাই", "bye", "goodbye") -> bye()
            hits(t, "কতটা", "কত ঘণ্টা", "ঘণ্টা", "সময়", "তারিখ", "কত তারিখ", "time", "date") ->
                time(tools.call("get_time", JSONObject()).optString("time"))
            hits(t, "ব্যাটারি", "চার্জ", "battery") ->
                battery(tools.call("get_battery", JSONObject()).optInt("level", 0))
            else -> null
        }
    }

    private fun hits(text: String, vararg words: String) =
        words.any { w -> Regex("(^|\\s)${Regex.escape(w)}(\\s|$)").containsMatchIn(text) }

    /** মডেলের উত্তরকে ZaRa-র বলার ধরণে আনে: markdown বাদ, ছোট বাক্য, ফল আগে। */
    fun polish(raw: String): String {
        var s = raw.trim()
            .replace(Regex("```.*?```", RegexOption.DOT_MATCHES_ALL), " ")
            .replace(Regex("[*_`#>]"), "")
            .replace(Regex("\\s+"), " ")
        val sentences = s.split(Regex("(?<=[।.!?])\\s+"))
            .map { it.trim() }.filter { it.isNotBlank() }.take(3)
        s = sentences.joinToString(" ")
        if (s.length > 280) s = s.take(277).trimEnd() + "…"
        return s.ifBlank { "বলো, আবার একটু পরিষ্কার করে?" }
    }
}
