package com.zaraai.app.agent

import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME
import android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS
import org.json.JSONObject

/**
 * Accessibility টুল — প্রতিটি ধাপে biometric + এক-বারের consent + রোল-গেট।
 * সার্ভিস না থাকলে স্পষ্ট বার্তা; কোনো নীরব/গোপন অ্যাকশন নেই।
 */
fun buildAccessibilityTools(consent: ConsentManager, guardian: VoiceGuardian): List<Tool> {
    fun gate(name: String): JSONObject? = when {
        !guardian.allows(name) -> JSONObject().put("error", "এই রোলে $name চালানো যাবে না।")
        !consent.consume(name) -> JSONObject().put("error", "$name-এর অনুমতি নেই।")
        ZaraAccessibilityService.instance == null ->
            JSONObject().put("error", "সেটিংস → অ্যাক্সেসিবিলিটি থেকে ZaRa চালু করো।")
        else -> null
    }

    return listOf(
        Tool("read_screen_text", "সক্রিয় স্ক্রিনের লেখা পড়ে", true) { _ ->
            gate("read_screen_text")?.let { return@Tool it }
            JSONObject().put("ok", true)
                .put("text", ZaraAccessibilityService.instance!!.readText())
        },
        Tool("tap_text", "দেখা যায় এমন লেখা/বাটনে টিপ দেয়", true) { a ->
            gate("tap_text")?.let { return@Tool it }
            val target = a.optString("text", "")
            if (target.isBlank()) return@Tool JSONObject().put("error", "কীতে টিপবো?")
            val ok = ZaraAccessibilityService.instance!!.tapText(target)
            JSONObject().put("ok", ok)
        },
        Tool("press_keys", "back / home / recents চাপে", true) { a ->
            gate("press_keys")?.let { return@Tool it }
            val action = when (a.optString("key").lowercase()) {
                "home" -> GLOBAL_ACTION_HOME
                "recents" -> GLOBAL_ACTION_RECENTS
                else -> GLOBAL_ACTION_BACK
            }
            JSONObject().put("ok", ZaraAccessibilityService.instance!!.press(action))
        },
        Tool("swipe_screen", "স্ক্রিনে swipe করে", true) { a ->
            gate("swipe_screen")?.let { return@Tool it }
            val ok = ZaraAccessibilityService.instance!!.swipe(
                a.optInt("x1", 500).toFloat(), a.optInt("y1", 1200).toFloat(),
                a.optInt("x2", 500).toFloat(), a.optInt("y2", 400).toFloat()
            )
            JSONObject().put("ok", ok)
        }
    )
}
