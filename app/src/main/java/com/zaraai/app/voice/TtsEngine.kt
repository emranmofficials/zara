package com.zaraai.app.voice

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import com.zaraai.app.data.VoiceProfile
import com.zaraai.app.diag.ZaraDiagnostics
import java.util.Locale

/**
 * ZaRa-র কন্ঠ-অর্কেস্ট্রেটর:
 * 1) তোমার বসানো on-device মডেল  2) মানুষের মতো neural TTS (তোমার key)
 * 3) সিস্টেম TTS — তৃতীয় পর্যায়ের fallback।
 * কোনো Maya voice pack / মডেল এখানে নেই।
 *
 * নীতি: TTS কখনো অ্যাপকে মারতে পারবে না — যেকোনো ব্যর্থতা লগ হয়ে নীরব fallback-এ শেষ।
 */
class TtsEngine(context: Context) {
    private var profile = VoiceProfile()
    private var ready = false
    private var systemSpeaking = false
    private var done: (() -> Unit)? = null
    private var cfg: TtsConfig? = null

    private val cloud = CloudTtsEngine(context)
    private val system: TextToSpeech? = runCatching {
        TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) runCatching { applyInternal(profile) }
                .onFailure { ZaraDiagnostics.log("TTS", "init voice failed", it) }
            if (!ready) ZaraDiagnostics.log("TTS", "engine init failed (status=$status)")
        }
    }.onFailure { ZaraDiagnostics.log("TTS", "TextToSpeech constructor failed", it) }.getOrNull()

    init {
        runCatching {
            system?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) { systemSpeaking = true }
                override fun onDone(utteranceId: String?) { finishSystem() }
                override fun onError(utteranceId: String?) { finishSystem() }
            })
        }.onFailure { ZaraDiagnostics.log("TTS", "listener setup failed", it) }
    }

    private fun finishSystem() {
        systemSpeaking = false
        VoiceSession.isSpeaking = false
        val cb = done
        done = null
        runCatching { cb?.invoke() }
            .onFailure { ZaraDiagnostics.log("TTS", "onDone callback failed", it) }
    }

    val isSpeaking: Boolean
        get() = cloud.isSpeaking || systemSpeaking || VoiceSession.isSpeaking

    fun configure(config: TtsConfig) {
        cfg = config
        profile = config.profile
        if (ready) runCatching { applyInternal(profile) }
            .onFailure { ZaraDiagnostics.log("TTS", "configure failed", it) }
    }

    fun applyProfile(p: VoiceProfile) {
        profile = p
        cfg = cfg?.copy(profile = p)
        if (ready) runCatching { applyInternal(p) }
            .onFailure { ZaraDiagnostics.log("TTS", "applyProfile failed", it) }
    }

    private fun applyInternal(p: VoiceProfile) {
        val tts = system ?: return
        val voices = runCatching { tts.voices.orEmpty() }.getOrDefault(emptyList())
        val chosen: Voice? = if (p.voiceName.isNotBlank())
            voices.firstOrNull { it.name == p.voiceName }
                ?: voices.firstOrNull { it.name.contains(p.voiceName, ignoreCase = true) }
        else {
            val bangla = voices.filter { it.locale.language.equals("bn", ignoreCase = true) }
            bangla.firstOrNull { v ->
                listOf("female", "woman", "women", "shimmer", "zira", "kanya", "priya", "samantha")
                    .any { k -> v.name.contains(k, ignoreCase = true) }
            } ?: bangla.firstOrNull { !it.isNetworkConnectionRequired }
            ?: bangla.firstOrNull()
        }
        if (chosen != null) tts.setVoice(chosen)
        else tts.setLanguage(Locale("bn", "BD"))
        tts.setSpeechRate(p.speed)
        tts.setPitch(p.pitch)
    }

    /** কথা বলা — কোনো exception বাইরে যাবে না। */
    fun speak(text: String, onDone: (() -> Unit)? = null) {
        try {
            stop()
            done = onDone
            val finish: () -> Unit = {
                val cb = done
                done = null
                runCatching { cb?.invoke() }
                    .onFailure { ZaraDiagnostics.log("TTS", "finish callback failed", it) }
            }
            val local = OnDeviceEngines.tts
            when {
                runCatching { local?.available() == true }.getOrDefault(false) && local != null -> {
                    runCatching { local!!.speak(text) }
                        .onFailure {
                            ZaraDiagnostics.log("TTS-local", "local speak failed", it)
                            speakSystem(text, finish)
                        }
                    VoiceSession.isSpeaking = true
                }
                cfg?.apiKey?.isNotBlank() == true -> {
                    cloud.speak(cfg!!, text, onDone = finish) { e ->
                        ZaraDiagnostics.log("TTS-cloud", "cloud failed, system fallback", e)
                        speakSystem(text, finish)
                    }
                }
                else -> speakSystem(text, finish)
            }
        } catch (t: Throwable) {
            ZaraDiagnostics.log("TTS", "speak crashed — system fallback", t)
            runCatching { speakSystem(text, onDone) }
                .onFailure { ZaraDiagnostics.log("TTS", "system fallback also failed", it) }
        }
    }

    private fun speakSystem(text: String, onDone: (() -> Unit)?) {
        val tts = system
        if (tts == null) {
            ZaraDiagnostics.log("TTS-system", "no engine on this device")
            runCatching { onDone?.invoke() }
            return
        }
        try {
            applyInternal(profile)
            done = onDone
            systemSpeaking = true
            VoiceSession.isSpeaking = true
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "zara")
        } catch (t: Throwable) {
            systemSpeaking = false
            VoiceSession.isSpeaking = false
            ZaraDiagnostics.log("TTS-system", "speak() threw", t)
            runCatching { onDone?.invoke() }
        }
    }

    /** বাকি কথা কাটা দাও — cloud/system/local সবই থামে। */
    fun stop() {
        runCatching { cloud.stop() }
        runCatching { system?.stop() }
        systemSpeaking = false
        runCatching { OnDeviceEngines.tts?.stop() }
        VoiceSession.isSpeaking = false
        val cb = done
        done = null
        runCatching { cb?.invoke() }
            .onFailure { ZaraDiagnostics.log("TTS", "stop callback failed", it) }
    }

    fun shutdown() {
        stop()
        runCatching { system?.shutdown() }
    }
}
