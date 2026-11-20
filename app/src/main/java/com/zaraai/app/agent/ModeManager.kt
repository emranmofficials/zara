package com.zaraai.app.agent

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * প্রসঙ্গ-সচেতন মোড — ঘুম/ড্রাইভিং/নীরব। Maya-র মতোই কথার সময় নির্ধারণ করে,
 * কিন্তু নীতি সম্পূর্ণ নিজস্ব ও স্থানীয়।
 */
object ModeManager {
    enum class Mode(val label: String) {
        NORMAL("স্বাভাবিক"), SLEEP("ঘুম"), DRIVING("ড্রাইভিং"), QUIET("নীরব")
    }

    private val _mode = MutableStateFlow(Mode.NORMAL)
    val mode: StateFlow<Mode> = _mode

    fun set(m: Mode) { _mode.value = m }

    /** priority ১ = জরুরি (কল/সতর্কতা), ২ = সাধারণ কথা। */
    fun allowSpeech(priority: Int = 2): Boolean = when (_mode.value) {
        Mode.NORMAL, Mode.DRIVING -> true
        Mode.SLEEP -> priority <= 1
        Mode.QUIET -> false
    }
}
