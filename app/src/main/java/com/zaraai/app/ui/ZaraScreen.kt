package com.zaraai.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.zaraai.app.R
import com.zaraai.app.agent.ModeManager
import com.zaraai.app.agent.VoiceGuardian
import com.zaraai.app.agent.ZaraBehavior
import com.zaraai.app.data.SpeechMode
import com.zaraai.app.diag.ZaraDiagnostics
import com.zaraai.app.voice.VoiceService

@Composable
fun ZaraScreen(vm: ZaraViewModel, onRequestScreen: () -> Unit) {
    val ui by vm.ui.collectAsState()
    val context = LocalContext.current
    var showSettings by remember { mutableStateOf(false) }
    var showDiag by remember { mutableStateOf(false) }
    var typed by remember { mutableStateOf("") }

    Column(Modifier.padding(16.dp)) {
        Text("ZaRa", style = MaterialTheme.typography.headlineLarge)
        Text(ui.status, style = MaterialTheme.typography.bodyMedium)

        Button(onClick = {
            val intent = Intent(context, VoiceService::class.java)
            if (ui.listening) {
                context.stopService(intent.setAction(VoiceService.ACTION_STOP))
            } else {
                ContextCompat.startForegroundService(
                    context, intent.setAction(VoiceService.ACTION_START)
                )
            }
        }) {
            Text(if (ui.listening) "থামো" else stringResource(R.string.mic_button))
        }

        if (ui.transcript.isNotBlank()) Text("তুমি: ${ui.transcript}")
        if (ui.reply.isNotBlank()) Text("ZaRa: ${ui.reply}")

        // API key ছাড়াও ZaRa-র আচরণ টেস্ট করার জন্য ছোট টেক্সট ইনপুট
        OutlinedTextField(
            typed, { typed = it },
            label = { Text("লিখে বলো — persona দেখো") },
            modifier = Modifier.fillMaxWidth()
        )
        Button(onClick = {
            if (typed.isNotBlank()) { vm.onText(typed); typed = "" }
        }) { Text("বলো") }

        // কথা বলার মোড — তুমি বেছে নাও ZaRa কেমন স্বরে কথা বলবে
        Text("কথা বলার মোড", style = MaterialTheme.typography.titleSmall)
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            SpeechMode.values().forEach { mode ->
                Button(
                    onClick = { vm.setMode(mode) },
                    modifier = Modifier.weight(1f)
                ) { Text(mode.label, maxLines = 1) }
            }
        }
        Button(onClick = { vm.previewVoice() }) { Text("কন্ঠ শুনে দেখো") }

        Button(onClick = { vm.onSystemStt() }) { Text("কী ছাড়া শুনো") }
        Button(onClick = onRequestScreen) { Text("স্ক্রিন অনুমতি") }
        Button(onClick = {
            runCatching {
                context.startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }) { Text("নোটিফিকেশন অনুমতি") }
        Button(onClick = {
            ZaraDiagnostics.flush(context)
            showDiag = true
        }) { Text("ডায়াগনস্টিক রিপোর্ট") }

        // প্রসঙ্গ-সচেতন মোড ও রোল — কখন কথা বলবে, কী করতে পারবে
        Text("মোড", style = MaterialTheme.typography.titleSmall)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            ModeManager.Mode.values().forEach { m ->
                Button(onClick = { vm.setDeviceMode(m) }, modifier = Modifier.weight(1f)) {
                    Text(m.label, maxLines = 1)
                }
            }
        }
        Text("রোল", style = MaterialTheme.typography.titleSmall)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            VoiceGuardian.Role.values().forEach { r ->
                Button(onClick = { vm.setRole(r) }, modifier = Modifier.weight(1f)) {
                    Text(r.label, maxLines = 1)
                }
            }
        }

        // নিজে লেখা স্কিল — কোনো সার্ভার থেকে আসে না
        var skillJson by remember { mutableStateOf("") }
        OutlinedTextField(skillJson, { skillJson = it },
            label = { Text("স্কিল JSON — {name,intent,steps:[{tool,args}]}") },
            modifier = Modifier.fillMaxWidth())
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(onClick = {
                if (skillJson.isNotBlank()) { vm.installSkill(skillJson); skillJson = "" }
            }, modifier = Modifier.weight(1f)) { Text("স্কিল যোগ", maxLines = 1) }
            Button(onClick = { vm.listSkills() }, modifier = Modifier.weight(1f)) {
                Text("স্কিল দেখো", maxLines = 1)
            }
        }
        var skillRun by remember { mutableStateOf("") }
        OutlinedTextField(skillRun, { skillRun = it },
            label = { Text("স্কিলের নাম") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { if (skillRun.isNotBlank()) vm.runSkill(skillRun) }) {
            Text("স্কিল চালাও")
        }

        var missionJson by remember { mutableStateOf("") }
        OutlinedTextField(missionJson, { missionJson = it },
            label = { Text("মিশন JSON — [{\"tool\":\"get_time\",\"args\":{}}]") },
            modifier = Modifier.fillMaxWidth())
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(onClick = {
                if (missionJson.isNotBlank()) vm.startMission(missionJson)
            }, modifier = Modifier.weight(1f)) { Text("মিশন চালাও", maxLines = 1) }
            Button(onClick = { vm.cancelMission() }, modifier = Modifier.weight(1f)) {
                Text("মিশন বাতিল", maxLines = 1)
            }
        }

        Button(onClick = { showSettings = !showSettings }) {
            Text(stringResource(R.string.settings))
        }
        if (showSettings) {
            var key by remember { mutableStateOf(ui.settings.apiKey) }
            var url by remember { mutableStateOf(ui.settings.baseUrl) }
            var voice by remember { mutableStateOf(ui.settings.voiceName) }
            var speed by remember { mutableStateOf(ui.settings.speed.toString()) }
            var pitch by remember { mutableStateOf(ui.settings.pitch.toString()) }
            var ttsModel by remember { mutableStateOf(ui.settings.ttsModel) }
            var ttsVoice by remember { mutableStateOf(ui.settings.ttsVoice) }

            OutlinedTextField(key, { key = it },
                label = { Text(stringResource(R.string.api_key_hint)) },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(url, { url = it },
                label = { Text(stringResource(R.string.base_url_hint)) },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(voice, { voice = it },
                label = { Text("বাংলা ভয়েস (খালি = স্বয়ংক্রিয়)") },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(speed, { speed = it },
                label = { Text("গতি — 1.0 স্বাভাবিক (ZaRa 1.08)") },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(pitch, { pitch = it },
                label = { Text("স্বর — 1.0 স্বাভাবিক") },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(ttsModel, { ttsModel = it },
                label = { Text("মানুষের কন্ঠ মডেল (gpt-4o-mini-tts / tts-1)") },
                modifier = Modifier.fillMaxWidth())
            OutlinedTextField(ttsVoice, { ttsVoice = it },
                label = { Text("কন্ঠ — nova / shimmer / onyx / alloy / echo / fable") },
                modifier = Modifier.fillMaxWidth())
            Button(onClick = {
                vm.saveSettings(ui.settings.copy(
                    apiKey = key, baseUrl = url, voiceName = voice,
                    speed = speed.toFloatOrNull() ?: 1.08f,
                    pitch = pitch.toFloatOrNull() ?: 1.0f,
                    ttsModel = ttsModel, ttsVoice = ttsVoice
                ))
                showSettings = false
            }) { Text("সংরক্ষণ") }
        }
    }

    if (showDiag) {
        AlertDialog(
            onDismissRequest = { showDiag = false },
            title = { Text("ZaRa ডায়াগনস্টিকস") },
            text = { Text(ZaraDiagnostics.report().take(4000)) },
            confirmButton = {
                Button(onClick = {
                    runCatching {
                        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        cm.setPrimaryClip(ClipData.newPlainText("ZaRa diagnostics", ZaraDiagnostics.report()))
                    }
                    showDiag = false
                }) { Text("কপি করো") }
            },
            dismissButton = { Button(onClick = { showDiag = false }) { Text("বন্ধ") } }
        )
    }

    ui.confirmation?.let { pending ->
        AlertDialog(
            onDismissRequest = { vm.resolveConfirmation(false) },
            title = { Text(stringResource(R.string.confirm_title)) },
            text = { Text(ZaraBehavior.confirmPrompt(pending.tool, pending.args)) },
            confirmButton = {
                Button(onClick = { vm.approveConfirmation() }) {
                    Text(stringResource(R.string.confirm_yes))
                }
            },
            dismissButton = {
                Button(onClick = { vm.resolveConfirmation(false) }) {
                    Text(stringResource(R.string.confirm_no))
                }
            }
        )
    }
}
