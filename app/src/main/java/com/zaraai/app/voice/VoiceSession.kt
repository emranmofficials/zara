package com.zaraai.app.voice

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Service ↔ UI-র মধ্যে ভাগ করা অবস্থা। Service mic+VAD করে; STT→Agent→TTS ViewModel করে। */
object VoiceSession {
    data class State(
        val listening: Boolean = false,
        val userSpeaking: Boolean = false,
        val status: String = "প্রস্তুত"
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state

    /** ViewModel এখানে নিজের STT→Agent→TTS হুক বসায়। */
    var onUtterance: (suspend (ShortArray) -> Unit)? = null

    /** ZaRa কথা বলার সময় ব্যবহারকারী কথা বললে barge-in ট্রিগার হয়। */
    var onBargeIn: (() -> Unit)? = null
    var isSpeaking: Boolean = false

    fun update(
        listening: Boolean? = null,
        userSpeaking: Boolean? = null,
        status: String? = null
    ) {
        val old = _state.value
        _state.value = old.copy(
            listening = listening ?: old.listening,
            userSpeaking = userSpeaking ?: old.userSpeaking,
            status = status ?: old.status
        )
    }

    fun bargeIn() { onBargeIn?.invoke() }
}
