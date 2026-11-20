package com.zaraai.app.voice

import android.content.Context
import android.media.MediaPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File

/**
 * মানুষের মতো কন্ঠ — user-Configured neural TTS endpoint (/audio/speech)।
 * কোনো Maya voice pack/native মডেল নেই; সব কিছু ব্যবহারকারীর নিজস্ব key ও endpoint।
 */
class CloudTtsEngine(private val context: Context) {
    private val client = OkHttpClient()
    private var player: MediaPlayer? = null
    private var scope: CoroutineScope? = null

    var isSpeaking: Boolean = false
        private set

    fun speak(cfg: TtsConfig, text: String, onDone: () -> Unit, onError: (Exception) -> Unit) {
        stop()
        isSpeaking = true
        VoiceSession.isSpeaking = true
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        scope!!.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val body = JSONObject()
                        .put("model", cfg.ttsModel)
                        .put("voice", cfg.ttsVoice)
                        .put("input", text)
                        .put("response_format", "mp3")
                    // gpt-4o-সিরিজের TTS-এ স্বর নির্দেশ দেওয়া যায়; অন্য endpoint এটা ignore করে
                    if (cfg.ttsModel.contains("gpt-4o", ignoreCase = true))
                        body.put(
                            "instructions",
                            "বাংলা (Bangla) বলো। উষ্ণ, আত্মবিশ্বাসী, চটপট নারী কন্ঠ। " +
                                "ছোট বাক্য, স্পষ্ট উচ্চারণ, সামান্য মজার ভঙ্গি।"
                        )
                    val payload = body.toString().toRequestBody("application/json".toMediaType())
                    val request = Request.Builder()
                        .url(cfg.baseUrl.trimEnd('/') + "/audio/speech")
                        .header("Authorization", "Bearer ${cfg.apiKey}")
                        .post(payload).build()
                    client.newCall(request).execute().use { r ->
                        if (!r.isSuccessful) throw IllegalStateException("TTS HTTP ${r.code}")
                        val file = File(context.cacheDir, "zara_speech.mp3")
                        file.writeBytes(r.body?.bytes() ?: throw IllegalStateException("খালি অডিও"))
                        file
                    }
                }
            }
            result.fold(
                onSuccess = { play(it, onDone) },
                onFailure = {
                    isSpeaking = false
                    VoiceSession.isSpeaking = false
                    com.zaraai.app.diag.ZaraDiagnostics.log("TTS-cloud", "network/TTS failed", it)
                    runCatching { onError(it as? Exception ?: Exception(it)) }
                }
            )
        }
    }

    private fun play(file: File, onDone: () -> Unit) {
        val mp = runCatching { MediaPlayer() }.getOrElse {
            com.zaraai.app.diag.ZaraDiagnostics.log("TTS-cloud", "MediaPlayer init failed", it)
            isSpeaking = false
            VoiceSession.isSpeaking = false
            runCatching { onDone() }
            return
        }
        player = mp
        try {
            mp.setDataSource(file.absolutePath)
            mp.prepare()
            mp.setOnCompletionListener {
                isSpeaking = false
                VoiceSession.isSpeaking = false
                file.delete()
                onDone()
            }
            mp.start()
        } catch (e: Exception) {
            isSpeaking = false
            VoiceSession.isSpeaking = false
            file.runCatching { delete() }
            onDone()
        }
    }

    fun stop() {
        player?.runCatching { stop(); release() }
        player = null
        scope?.cancel()
        scope = null
        isSpeaking = false
        VoiceSession.isSpeaking = false
    }
}
