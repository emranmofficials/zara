package com.zaraai.app.voice

/** STT interface. v1 uses a user-supplied OpenAI-compatible /audio/transcriptions endpoint. */
interface SttEngine {
    suspend fun transcribe(pcm: ShortArray): String
    suspend fun cancel() {}
}
