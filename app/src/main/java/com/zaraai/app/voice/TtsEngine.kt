package com.zaraai.app.voice

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import com.zaraai.app.data.VoiceProfile
import java.util.Locale

/**
 * ZaRa-র কন্ঠ-অর্কেস্ট্রেটর:
 * 1) তোমার বসানো on-device মডেল  2) মানুষের মতো neural TTS (তোমার key)
 * 3) সিস্টেম TTS — তৃতীয় পর্যায়ের fallback।
 * কোনো Maya voice pack / মডেল এখানে নেই।
 */
class TtsEngine(context: Context) {
    private var profile = VoiceProfile()
    private var ready = false
    private var systemSpeaking = false
    private var done: (() -> Unit)? = null
    private var cfg: TtsConfig? = null

    private val cloud = CloudTtsEngine(context)
    private val system = TextToSpeech(context.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
        if (ready) applyInternal(profile)
    }

    init {
        system.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) { systemSpeaking = true }
            override fun onDone(utteranceId: String?) { finishSystem() }
            override fun onError(utteranceId: String?) { finishSystem() }
        })
    }

    private fun finishSystem() {
        systemSpeaking = false
        VoiceSession.isSpeaking = false
        done?.invoke()
        done = null
    }

    val isSpeaking: Boolean
        get() = cloud.isSpeaking || systemSpeaking || VoiceSession.isSpeaking

    fun configure(config: TtsConfig) {
        cfg = config
        profile = config.profile
        if (ready) applyInternal(profile)
    }

    fun applyProfile(p: VoiceProfile) {
        profile = p
        cfg = cfg?.copy(profile = p)
        if (ready) applyInternal(p)
    }

    private fun applyInternal(p: VoiceProfile) {
        val chosen: Voice? = if (p.voiceName.isNotBlank())
            system.voices?.firstOrNull { it.name == p.voiceName }
        else
            system.voices?.firstOrNull {
                it.locale.language.equals("bn", ignoreCase = true) &&
                    !it.isNetworkConnectionRequired
            }
        if (chosen != null) system.setVoice(chosen) else system.setLanguage(Locale("bn", "BD"))
        system.setSpeechRate(p.speed)
        system.setPitch(p.pitch)
    }

    fun speak(text: String, onDone: (() -> Unit)? = null) {
        stop()
        done = onDone
        val finish = { done?.invoke(); done = null }

        val local = OnDeviceEngines.tts
        when {
            local?.available() == true -> {
                local.speak(text)
                VoiceSession.isSpeaking = true
            }
            cfg?.apiKey?.isNotBlank() == true -> {
                cloud.speak(cfg!!, text, onDone = finish, onError = { speakSystem(text, finish) })
            }
            else -> speakSystem(text, finish)
        }
    }

    private fun speakSystem(text: String, onDone: () -> Unit) {
        applyInternal(profile)
        done = onDone
        systemSpeaking = true
        VoiceSession.isSpeaking = true
        system.speak(text, TextToSpeech.QUEUE_FLUSH, null, "zara")
    }

    /** বাকি কথা কাটা দাও — cloud/system/local সবই থামে। */
    fun stop() {
        cloud.stop()
        system.stop()
        systemSpeaking = false
        OnDeviceEngines.tts?.stop()
        VoiceSession.isSpeaking = false
        done?.invoke()
        done = null
    }

    fun shutdown() {
        stop()
        system.shutdown()
    }
}
