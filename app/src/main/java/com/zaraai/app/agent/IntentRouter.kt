package com.zaraai.app.agent

import org.json.JSONObject

/**
 * Maya-র intent-classifier/fast-path-এর নিজস্ব বাংলা বাস্তবায়ন — মডেল না ডাকেই
 * নিরাপদ, সাধারণ কাজ চালায়। কোনো Maya keyword-সেট বা স্ক্রিপ্ট কপি করা হয়নি।
 * শুধু non-privileged টুল এখান থেকে চলে; বাকি সব মডেল + অনুমতির মাধ্যমে।
 */
object IntentRouter {
    data class Hit(val tool: String, val args: JSONObject = JSONObject(), val reply: String? = null)

    private data class Rule(val words: List<String>, val tool: String, val args: () -> JSONObject)

    private fun rule(words: String, tool: String, args: () -> JSONObject = { JSONObject() }) =
        Rule(words.split("|"), tool, args)

    private val rules = listOf(
        rule("সময়|কতটা|তারিখ|ঘণ্টা|time|date", "get_time") { JSONObject() },
        rule("ব্যাটারি|চার্জ|battery", "get_battery") { JSONObject() },
        rule("ভলিউম বাড়া|আওয়াজ বাড়া|volume up", "set_volume") { JSONObject().put("delta", 10) },
        rule("ভলিউম কমা|আওয়াজ কমা|volume down", "set_volume") { JSONObject().put("delta", -10) },
        rule("মিউট|নীরব কর|mute", "set_volume") { JSONObject().put("level", 0) },
        rule("রিংগার সাইলেন্ট|সাইলেন্ট মোড|silent mode", "set_ringer") { JSONObject().put("mode", "silent") },
        rule("ভাইব্রেট|vibrate", "set_ringer") { JSONObject().put("mode", "vibrate") },
        rule("সাধারণ রিং|রিংগার নরমাল|ringer normal", "set_ringer") { JSONObject().put("mode", "normal") },
        rule("উজ্জ্বল বাড়া|ব্রাইটনেস বাড়া|brightness up", "set_brightness") { JSONObject().put("delta", 25) },
        rule("উজ্জ্বল কমা|ব্রাইটনেস কমা|brightness down", "set_brightness") { JSONObject().put("delta", -25) },
        rule("টর্চ অন|ফ্ল্যাশ অন|torch on", "set_torch") { JSONObject().put("on", true) },
        rule("টর্চ অফ|ফ্ল্যাশ অফ|torch off", "set_torch") { JSONObject().put("on", false) },
        rule("ঘুম|ঘুমের মোড|go to sleep|sleep mode", "go_to_sleep") { JSONObject() },
        rule("ড্রাইভিং মোড|driving mode", "set_driving_mode") { JSONObject() },
        rule("স্বাভাবিক মোড|normal mode", "set_normal_mode") { JSONObject() },
        rule("সেটিংস খোল|open settings", "open_settings") { JSONObject() },
        rule("ওয়েবে খুঁজ|গুগলে খুঁজ|search web|web search", "search_web") { JSONObject() },
        rule("গান চালা|প্লে কর|play music|next song|পরের গান", "media_control") { JSONObject().put("action", "next") },
        rule("গান থামা|pause music|থামাও", "media_control") { JSONObject().put("action", "pause") },
        rule("নোট মনে রাখ|মনে রাখবি|remember that", "add_note") { JSONObject() },
        rule("আগের কথা মনে আছে|recall memory|মনে করিয়ে দে", "recall_notes") { JSONObject() },
        rule("অ্যাপ খোল|open app", "open_app") { JSONObject() }
    )

    /** ম্যাচ হলে Hit; নাহলে null — কলার তখন মডেল/সাধারণ উত্তরের দিকে যায়। */
    fun match(text: String): Hit? {
        val t = text.trim().lowercase()
        return rules.firstOrNull { rule ->
            rule.words.any { w ->
                Regex("(^|\\s)${Regex.escape(w)}(\\s|$)").containsMatchIn(t)
                    || (w.contains(" ") && t.contains(w))
            }
        }?.let { Hit(it.tool, it.args()) }
    }
}
