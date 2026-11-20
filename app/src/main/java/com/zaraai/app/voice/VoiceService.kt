package com.zaraai.app.voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch

/** Foreground mic capture + VAD. Permission-gated, visible notification, stoppable. */
class VoiceService : Service() {
    companion object {
        const val ACTION_START = "com.zaraai.app.voice.START"
        const val ACTION_STOP = "com.zaraai.app.voice.STOP"
        private const val CHANNEL = "zara_voice"
        private const val NOTIF_ID = 1
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "ZaRa ভয়েস", NotificationManager.IMPORTANCE_LOW)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val n = notification()
                if (Build.VERSION.SDK_INT >= 29)
                    startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                else startForeground(NOTIF_ID, n)
                startCapture()
            }
            ACTION_STOP -> {
                scope.cancel()
                VoiceSession.update(listening = false, userSpeaking = false, status = "থামা হয়েছে")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun notification(): Notification =
        Notification.Builder(this, CHANNEL)
            .setContentTitle("ZaRa")
            .setContentText("শোনছি…")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()

    private fun startCapture() {
        VoiceSession.update(listening = true, status = "শোনছি…")
        scope.launch {
            runCatching {
                val vad = Vad()
                AudioCapture().pcmStream()
                .catch { e ->
                    com.zaraai.app.diag.ZaraDiagnostics.log("STT", "mic stream error", e)
                    VoiceSession.update(listening = false, status = "মাইক ত্রুটি: ${e.message}")
                }
                .collect { frame ->
                    val speaking = vad.isSpeech(frame)
                    VoiceSession.update(userSpeaking = speaking)
                    // ZaRa কথা বলছে আর ব্যবহারকারী কথা বলা শুরু করলে — বাকি কাটা দাও
                    if (speaking && VoiceSession.isSpeaking) VoiceSession.bargeIn()
                    vad.feed(frame)?.let { utterance ->
                        VoiceSession.update(status = "ভাবছি…")
                        VoiceSession.onUtterance?.invoke(utterance)
                    }
                }
            }.onFailure { e ->
                com.zaraai.app.diag.ZaraDiagnostics.log("STT", "mic capture crashed", e)
                VoiceSession.update(listening = false, status = "মাইক ত্রুটি: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        VoiceSession.update(listening = false, userSpeaking = false, status = "প্রস্তুত")
        super.onDestroy()
    }
}
