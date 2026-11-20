package com.zaraai.app.voice

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Maya-র MayaRecognitionService-র নিজস্ব সমতুল্য — সিস্টেম STT-কে বাংলা ('bn-BD')
 * দিয়ে অন্য অ্যাপের কাছে উপলব্ধ করে। কোনো Maya STT মডেল বা সার্ভার নেই।
 */
class ZaraRecognitionService : RecognitionService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var recognizer: SpeechRecognizer? = null

    override fun onStartListening(intent: Intent, listener: Callback) {
        runCatching { listener.onStartListening() }
        recognizer?.destroy()
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            runCatching { listener.onError(android.speech.SpeechRecognizer.ERROR_CLIENT) }
            return
        }
        val sr = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = sr
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onError(error: Int) = runCatching { listener.onError(error) }.let { Unit }
            override fun onResults(results: Bundle?) {
                val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?: arrayListOf()
                val b = Bundle().apply {
                    putStringArrayList(RecognizerIntent.EXTRA_RESULTS, texts)
                    putFloatArray(RecognizerIntent.EXTRA_CONFIDENCE_SCORES, FloatArray(texts.size) { 1f })
                }
                runCatching { listener.onResults(b) }
            }
            override fun onPartialResults(partial: Bundle?) = runCatching { listener.onPartialResults(partial) }.let { Unit }
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "bn-BD")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        sr.startListening(i)
    }

    override fun onCancel(listener: Callback) {
        recognizer?.cancel()
        runCatching { listener.onCancel() }
    }

    override fun onStopListening(listener: Callback) {
        recognizer?.stopListening()
    }

    override fun onDestroy() {
        scope.cancel()
        recognizer?.destroy()
        super.onDestroy()
    }
}
