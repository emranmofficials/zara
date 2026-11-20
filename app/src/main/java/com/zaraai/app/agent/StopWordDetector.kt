package com.zaraai.app.agent

/**
 * Barge-in / cancel detection — বাংলা প্রথম, ইংরেজি/hindi fallback।
 * Scans at most MAX_TOKENS tokens (৬-টোকন barge-in window)।
 */
object StopWordDetector {
    private const val MAX_TOKENS = 6
    private val CANCEL = setOf(
        "থামো", "থাম", "থেমে", "রুক", "বন্ধ", "বাদ", "দাও", "চলো", "না",
        "stop", "wait", "abort", "cancel", "ruk", "ruko", "chhodo"
    )
    private val SOFT = setOf(
        "আচ্ছা", "হ্যাঁ", "না", "দয়া", "করে", "এখন", "জারা",
        "bas", "ok", "okay", "achha", "haan", "nahi", "please", "plz", "abhi"
    )

    fun isStop(text: String): Boolean {
        val tokens = text.lowercase().split(Regex("[^a-z\u0980-\u09ff]+")).filter { it.isNotBlank() }
        return tokens.take(MAX_TOKENS).any { it in CANCEL } ||
            (tokens.size <= 2 && tokens.all { it in SOFT })
    }
}
