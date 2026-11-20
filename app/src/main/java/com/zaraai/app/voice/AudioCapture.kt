package com.zaraai.app.voice

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext

/** 16 kHz mono PCM capture. VOICE_COMMUNICATION + AcousticEchoCanceler = v1 echo control. */
class AudioCapture {
    private val sampleRate = 16000
    private val bufferSize = AudioRecord.getMinBufferSize(
        sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
    ).coerceAtLeast(sampleRate / 2)

    fun pcmStream(): Flow<ShortArray> = flow {
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate, AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT, bufferSize
        )
        val aec = if (AcousticEchoCanceler.isAvailable())
            AcousticEchoCanceler.create(recorder.audioSessionId) else null
        aec?.enabled = true
        val buffer = ShortArray(bufferSize / 2)
        try {
            recorder.startRecording()
            withContext(Dispatchers.IO) {
                while (isActive) {
                    val n = recorder.read(buffer, 0, buffer.size)
                    if (n > 0) emit(buffer.copyOf(n))
                }
            }
        } finally {
            recorder.stop(); recorder.release(); aec?.release()
        }
    }
}
