package com.zaraai.app.voice

/** v1: wake word from transcribed text — বাংলা প্রথম, ইংরেজি fallback। TFLite keyword spotter later. */
class WakeWordDetector(
    private val wakes: List<String> = listOf("ও জারা", "জারা", "zara", "ok zara")
) {
    fun matches(text: String): String? {
        val lower = text.trim().lowercase()
        return wakes.firstOrNull { lower.startsWith(it) }?.let {
            lower.removePrefix(it).trim()
        }
    }
}
