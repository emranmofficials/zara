package com.zaraai.app.voice

/**
 * তোমার নিজস্ব অন-ডিভাইস মডেল বসানোর extension point।
 * কোনো মডেলই অ্যাপের সাথে বান্ডেল করা হয়নি — কোনো Maya/Termux অ্যাসেট নয়।
 * Piper/Kokoro (TTS) বা Whisper-Tiny/ Silero (STT) এখানে বসাতে পারো।
 */
interface OnDeviceStt {
    fun available(): Boolean
    suspend fun transcribe(pcm: ShortArray): String
    fun cancel() {}
}

interface OnDeviceTts {
    fun available(): Boolean
    fun speak(text: String)
    fun stop()
    fun shutdown()
}

object OnDeviceEngines {
    @Volatile var stt: OnDeviceStt? = null
        private set
    @Volatile var tts: OnDeviceTts? = null
        private set

    fun installStt(engine: OnDeviceStt?) { stt = engine }
    fun installTts(engine: OnDeviceTts?) { tts = engine }
}
