package com.zaraai.app.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsStore by preferencesDataStore("zara_settings")

data class ZaraSettings(
    val apiKey: String = "",
    val baseUrl: String = "https://api.openai.com/v1",
    val model: String = "gpt-4o-mini",
    val sttModel: String = "whisper-1",
    val voiceName: String = "",
    val speed: Float = SpeechMode.PUNCHY.rate,
    val pitch: Float = SpeechMode.PUNCHY.pitch,
    val speechMode: String = SpeechMode.PUNCHY.name,
    val ttsModel: String = "gpt-4o-mini-tts",
    val ttsVoice: String = "shimmer",
    /** ব্যবহারকারীর নিজস্ব connector endpoint — JSON map, কোনো Maya host নয়। */
    val connectorsJson: String = "{}"
)

class Settings(private val context: Context) {
    private val keyApi = stringPreferencesKey("api_key")
    private val keyUrl = stringPreferencesKey("base_url")
    private val keyModel = stringPreferencesKey("model")
    private val keyVoice = stringPreferencesKey("voice_name")
    private val keySpeed = stringPreferencesKey("speed")
    private val keyPitch = stringPreferencesKey("pitch")
    private val keyMode = stringPreferencesKey("speech_mode")
    private val keyTtsModel = stringPreferencesKey("tts_model")
    private val keyTtsVoice = stringPreferencesKey("tts_voice")
    private val keyConnectors = stringPreferencesKey("connectors_json")

    val flow: Flow<ZaraSettings> = context.settingsStore.data.map { p ->
        val mode = SpeechMode.from(p[keyMode])
        ZaraSettings(
            apiKey = p[keyApi] ?: "",
            baseUrl = p[keyUrl] ?: "https://api.openai.com/v1",
            model = p[keyModel] ?: "gpt-4o-mini",
            voiceName = p[keyVoice] ?: "",
            speed = p[keySpeed]?.toFloatOrNull() ?: mode.rate,
            pitch = p[keyPitch]?.toFloatOrNull() ?: mode.pitch,
            speechMode = mode.name,
            ttsModel = p[keyTtsModel] ?: "gpt-4o-mini-tts",
            ttsVoice = p[keyTtsVoice] ?: "shimmer",
            connectorsJson = p[keyConnectors] ?: "{}"
        )
    }

    suspend fun save(s: ZaraSettings) = context.settingsStore.edit { p ->
        p[keyApi] = s.apiKey
        p[keyUrl] = s.baseUrl
        p[keyModel] = s.model
        p[keyVoice] = s.voiceName
        p[keySpeed] = s.speed.toString()
        p[keyPitch] = s.pitch.toString()
        p[keyMode] = s.speechMode
        p[keyTtsModel] = s.ttsModel
        p[keyTtsVoice] = s.ttsVoice
        p[keyConnectors] = s.connectorsJson
    }
}
