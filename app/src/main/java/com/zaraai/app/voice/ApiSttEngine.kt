package com.zaraai.app.voice

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Calls a user-configured endpoint with the user's OWN key.
 * No key, host, or credential is embedded in this app.
 */
class ApiSttEngine(
    private val baseUrl: String,
    private val apiKey: String,
    private val model: String = "whisper-1"
) : SttEngine {
    private val client = OkHttpClient()

    override suspend fun transcribe(pcm: ShortArray): String {
        val wav = pcmToWav(pcm)
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("model", model)
            .addFormDataPart("language", "bn") // বাংলা — প্রধান ভাষা
            .addFormDataPart("file", "speech.wav",
                wav.toRequestBody("audio/wav".toMediaType()))
            .build()
        val request = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/audio/transcriptions")
            .header("Authorization", "Bearer $apiKey")
            .post(body).build()
        return client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IllegalStateException("STT HTTP ${response.code}")
            JSONObject(response.body!!.string()).optString("text", "")
        }
    }

    private fun pcmToWav(pcm: ShortArray): ByteArray {
        val out = ByteArrayOutputStream()
        val bytes = ByteArray(pcm.size * 2)
        for (i in pcm.indices) {
            bytes[i * 2] = (pcm[i].toInt() and 0xff).toByte()
            bytes[i * 2 + 1] = (pcm[i].toInt() shr 8 and 0xff).toByte()
        }
        val dataSize = bytes.size
        out.write("RIFF".toByteArray()); out.write(intLe(36 + dataSize))
        out.write("WAVEfmt ".toByteArray()); out.write(intLe(16))
        out.write(shortLe(1)); out.write(shortLe(1)); out.write(intLe(16000))
        out.write(intLe(32000)); out.write(shortLe(2)); out.write(shortLe(16))
        out.write("data".toByteArray()); out.write(intLe(dataSize)); out.write(bytes)
        return out.toByteArray()
    }
    private fun intLe(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
    private fun shortLe(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte())
}
