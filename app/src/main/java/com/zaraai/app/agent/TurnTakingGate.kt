package com.zaraai.app.agent

/** Decides whether the assistant should speak now, to avoid talking over the user. */
object TurnTakingGate {
    enum class Decision { SPEAK, DEFER, SUPPRESS }

    fun decide(userIsSpeaking: Boolean, partialTranscriptReady: Boolean, toolRunning: Boolean): Decision =
        when {
            userIsSpeaking -> Decision.DEFER
            toolRunning && !partialTranscriptReady -> Decision.SUPPRESS
            else -> Decision.SPEAK
        }
}
