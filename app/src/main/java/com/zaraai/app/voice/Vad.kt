package com.zaraai.app.voice

/** v1: energy-based VAD. Silero-VAD/TFLite model can replace this later. */
class Vad(private val threshold: Short = 900, private val silenceFrames: Int = 20) {
    private var silent = 0
    private val speech = mutableListOf<Short>()

    /** v1.1: barge-in / turn-taking-এর জন্য সিস্টেমকে জানানো হয় এখন ব্যবহারকারী কথা বলছে কি না। */
    fun isSpeech(frame: ShortArray): Boolean {
        if (frame.isEmpty()) return false
        val rms = kotlin.math.sqrt(frame.fold(0.0) { acc, s -> acc + s.toDouble() * s } / frame.size)
        return rms > threshold
    }

    /** Returns a completed utterance when silence follows speech. */
    fun feed(frame: ShortArray): ShortArray? {
        if (isSpeech(frame)) {
            silent = 0; speech.addAll(frame.asIterable())
        } else if (speech.isNotEmpty()) {
            silent++
            if (silent >= silenceFrames) {
                val out = speech.toShortArray(); speech.clear(); silent = 0; return out
            }
        }
        return null
    }
}
