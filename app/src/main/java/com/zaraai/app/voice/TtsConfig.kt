package com.zaraai.app.voice

import com.zaraai.app.data.VoiceProfile

/** নিউরাল TTS-র কনফিগ — সব ব্যবহারকারীর নিজস্ব, কোনো embedded key নয়। */
data class TtsConfig(
    val apiKey: String,
    val baseUrl: String,
    val ttsModel: String,
    val ttsVoice: String,
    val profile: VoiceProfile
)
