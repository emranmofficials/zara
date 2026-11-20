package com.zaraai.app.ui

import android.content.Intent
import android.provider.Settings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.fragment.app.FragmentActivity
import com.zaraai.app.agent.ModeManager
import com.zaraai.app.agent.VoiceGuardian
import org.json.JSONArray
import org.json.JSONObject

/** Maya-র ১৩টি Activity-র নিজস্ব সমতুল্য — একটি Compose host-এ ১৩টি রুট। */
enum class ZaRaRoute(val label: String) {
    HOME("হোম"),
    ASSISTANT("সহকারী"),
    RECOGNITION("শ্রবণ"),
    VOICE_INTERACTION("ভয়েস"),
    CONNECTORS("কনেক্টর"),
    BROWSER("ব্রাউজার"),
    TASK_CONSOLE("কনসোল"),
    FACE_GUARD("ফেস গার্ড"),
    WATCH_GUARD("গার্ড"),
    UNLOCK("আনলক"),
    SCREEN_SHARE("স্ক্রিন"),
    PERMISSIONS("অনুমতি"),
    SEND_TO_PC("PC তে পাঠাও")
}

@Composable
fun ZaRaApp(
    vm: ZaraViewModel,
    activity: FragmentActivity,
    onRequestScreen: () -> Unit,
    startRoute: ZaRaRoute = ZaRaRoute.HOME
) {
    var route by remember { mutableStateOf(startRoute) }
    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(8.dp)
        ) {
            ZaRaRoute.values().forEach { r ->
                Button(
                    onClick = { route = r },
                    modifier = Modifier.padding(end = 4.dp)
                ) { Text(r.label, maxLines = 1) }
            }
        }
        Box(
            Modifier.fillMaxSize()
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            when (route) {
                ZaRaRoute.HOME -> ZaraScreen(vm, onRequestScreen)
                ZaRaRoute.ASSISTANT -> AssistantScreen(vm)
                ZaRaRoute.RECOGNITION -> RecognitionScreen(vm)
                ZaRaRoute.VOICE_INTERACTION -> VoiceInteractionScreen(vm)
                ZaRaRoute.CONNECTORS -> ConnectorsScreen(vm)
                ZaRaRoute.BROWSER -> BrowserScreen()
                ZaRaRoute.TASK_CONSOLE -> TaskConsoleScreen(vm)
                ZaRaRoute.FACE_GUARD -> FaceGuardScreen(activity, vm)
                ZaRaRoute.WATCH_GUARD -> WatchGuardScreen(vm)
                ZaRaRoute.UNLOCK -> UnlockScreen(activity, vm)
                ZaRaRoute.SCREEN_SHARE -> ScreenShareScreen(vm, onRequestScreen)
                ZaRaRoute.PERMISSIONS -> ToolPermissionScreen(vm)
                ZaRaRoute.SEND_TO_PC -> SendToPcScreen(vm)
            }
        }
    }
}

/** ২ — ACTION_ASSIST entry */
@Composable
fun AssistantScreen(vm: ZaraViewModel) {
    val ui by vm.ui.collectAsState()
    Column {
        Text("সহকারী", style = MaterialTheme.typography.headlineSmall)
        Text("ACTION_ASSIST দিয়ে ZaRa খোলে। status: ${ui.status}")
        Button(onClick = { vm.onSystemStt() }) { Text("শুনুন") }
    }
}

/** ৩ — সিস্টেম STT সার্ভিসের UI */
@Composable
fun RecognitionScreen(vm: ZaraViewModel) {
    val ui by vm.ui.collectAsState()
    Column {
        Text("শ্রবণ", style = MaterialTheme.typography.headlineSmall)
        Text("bn-BD · কোনো API key লাগবে না")
        Button(onClick = { vm.onSystemStt() }) { Text("কথা বলুন") }
        if (ui.transcript.isNotBlank()) Text("তুমি: ${ui.transcript}")
    }
}

/** ৪ — VoiceInteractionSession status */
@Composable
fun VoiceInteractionScreen(vm: ZaraViewModel) {
    val ui by vm.ui.collectAsState()
    Column {
        Text("ভয়েস ইন্টারঅ্যাকশন", style = MaterialTheme.typography.headlineSmall)
        Text("Android Assistant হিসেবে ZaRa বেছে নিতে সেটিংস → Assistant")
        Text("listening: ${ui.listening} · status: ${ui.status}")
        Button(onClick = { vm.previewVoice() }) { Text("কন্ঠ পরীক্ষা") }
    }
}

/** ৫ — নিজস্ব OAuth connector + PKCE */
@Composable
fun ConnectorsScreen(vm: ZaraViewModel) {
    val ui by vm.ui.collectAsState()
    var json by remember { mutableStateOf(ui.settings.connectorsJson) }
    var state by remember { mutableStateOf("") }
    var validation by remember { mutableStateOf("") }
    Column {
        Text("কনেক্টর", style = MaterialTheme.typography.headlineSmall)
        Text("শুধু তোমার নিজস্ব https endpoint। কোনো Maya host নেই।")
        OutlinedTextField(
            json, { json = it },
            label = { Text("connector JSON — {\"weather\":\"https://…/{q}\",\"key\":\"…\"}") },
            modifier = Modifier.fillMaxWidth()
        )
        Row {
            Button(onClick = { vm.saveSettings(ui.settings.copy(connectorsJson = json)) }) {
                Text("সংরক্ষণ")
            }
            Button(onClick = {
                state = vm.oauthBegin()
                validation = ""
            }) { Text("PKCE state") }
        }
        if (state.isNotBlank()) {
            Text("state: $state")
            Button(onClick = { validation = vm.oauthValidate(state).toString() }) {
                Text("state যাচাই")
            }
            if (validation.isNotBlank()) Text("ফলাফল: $validation")
        }
    }
}

/** ৬ — in-app browser + read_page (শুধু দেখা, নীরব আপলোড নেই) */
@Composable
fun BrowserScreen() {
    var url by remember { mutableStateOf("https://example.com") }
    var pageText by remember { mutableStateOf("") }
    val web = remember { mutableStateOf<WebView?>(null) }
    Column {
        Text("ব্রাউজার", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(url, { url = it }, label = { Text("url") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { web.value?.loadUrl(url) }) { Text("খোলো") }
        AndroidView(
            factory = { ctx ->
                WebView(ctx).apply {
                    webViewClient = object : WebViewClient() {
                        override fun onPageFinished(view: WebView?, loadedUrl: String?) {
                            view?.evaluateJavascript("document.body.innerText") { raw ->
                                pageText = raw?.trim('"')?.take(2000).orEmpty()
                            }
                        }
                    }
                    settings.javaScriptEnabled = true
                    web.value = this
                    loadUrl(url)
                }
            },
            modifier = Modifier.fillMaxWidth().height(260.dp)
        )
        Text("পড়া লেখা:", style = MaterialTheme.typography.titleSmall)
        Text(pageText.take(400))
    }
}

/** ৭ — টুল কনসোল: log/latency, কোনো shell নেই */
@Composable
fun TaskConsoleScreen(vm: ZaraViewModel) {
    val stats: JSONArray = vm.toolStats()
    var imported by remember { mutableStateOf("") }
    var exported by remember { mutableStateOf("") }
    Column {
        Text("টুল কনসোল", style = MaterialTheme.typography.headlineSmall)
        Text("এখানে শুধু টুলের log/latency দেখা যায় — কোনো remote shell নেই।")
        Button(onClick = { vm.missionStatus() }) { Text("মিশন স্ট্যাটাস") }
        for (i in 0 until stats.length()) {
            val o = stats.optJSONObject(i) ?: continue
            Text("${o.optString("tool")} — ${o.optInt("ms")}ms · ok=${o.optBoolean("ok")}")
        }

        Text("নিজস্ব ডাটা", style = MaterialTheme.typography.titleSmall)
        Text("স্থানীয় ইতিহাস: ${vm.historySize()} বার্তা। এক্সপোর্টে API key থাকে না।")
        Row {
            Button(onClick = { exported = vm.exportData() }) { Text("এক্সপোর্ট") }
            Button(onClick = { vm.clearHistory() }) { Text("ইতিহাস মুছো") }
        }
        if (exported.isNotBlank()) {
            Text(exported.take(300), style = MaterialTheme.typography.bodySmall)
        }
        OutlinedTextField(
            imported, { imported = it },
            label = { Text("নিজের JSON/CSV ব্যাকআপ পেস্ট করো") },
            modifier = Modifier.fillMaxWidth()
        )
        Button(onClick = {
            if (imported.isNotBlank()) {
                vm.importData(imported)
                imported = ""
            }
        }) { Text("আমদানি করো") }
    }
}

/** ৮ — biometric + face hook */
@Composable
fun FaceGuardScreen(activity: FragmentActivity, vm: ZaraViewModel) {
    Column {
        Text("ফেস গার্ড", style = MaterialTheme.typography.headlineSmall)
        Text("Android BiometricPrompt দিয়ে unlock; নিজস্ব face model hook যোগ করা যাবে।")
        Button(onClick = {
            SecureGate.requireUnlock(activity, { vm.setRole(VoiceGuardian.Role.OWNER) })
        }) { Text("unlock দিয়ে নিশ্চিত হও") }
    }
}

/** ৯ — দৃশ্যমান গার্ড, কোনো covert ছবি/সাইরেন নেই */
@Composable
fun WatchGuardScreen(vm: ZaraViewModel) {
    var on by remember { mutableStateOf(false) }
    Column {
        Text("ডিভাইস গার্ড", style = MaterialTheme.typography.headlineSmall)
        Text("শুধু দৃশ্যমান ইঙ্গিত ও biometric — অনধিকৃত স্পর্শে গোপন ছবি তোলা হয় না।")
        Row {
            Text("গার্ড ${if (on) "চালু" else "বন্ধ"}")
            Switch(checked = on, onValueChange = {
                on = it
                if (it) vm.setDeviceMode(ModeManager.Mode.NORMAL)
            })
        }
    }
}

/** ১০ — unlock screen */
@Composable
fun UnlockScreen(activity: FragmentActivity, vm: ZaraViewModel) {
    Column {
        Text("আনলক", style = MaterialTheme.typography.headlineSmall)
        Text("ZaRa কোনো PIN/pattern রাখে না — সিস্টেমই যাচাই করে।")
        Button(onClick = { SecureGate.requireUnlock(activity, { vm.previewVoice() }) }) {
            Text("unlock করো")
        }
    }
}

/** ১১ — MediaProjection consent */
@Composable
fun ScreenShareScreen(vm: ZaraViewModel, onRequestScreen: () -> Unit) {
    Column {
        Text("স্ক্রিন শেয়ার", style = MaterialTheme.typography.headlineSmall)
        Text("শুধু Android consent dialog + সবসময় দৃশ্যমান notification। ফ্রেম শুধু এই ডিভাইসে।")
        Button(onClick = onRequestScreen) { Text("অনুমতি চাও") }
        Button(onClick = { vm.stopScreen() }) { Text("থামাও") }
    }
}

/** ১২ — runtime permission / অ্যাক্সেসিবিলিটি */
@Composable
fun ToolPermissionScreen(vm: ZaraViewModel) {
    val context = LocalContext.current
    var boot by remember { mutableStateOf(vm.bootRearmEnabled()) }
    Column {
        Text("অনুমতি", style = MaterialTheme.typography.headlineSmall)
        Button(onClick = {
            runCatching {
                vm.toolStats()
                context.startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }) { Text("অ্যাক্সেসিবিলিটি অনুমতি") }
        Button(onClick = {
            runCatching {
                context.startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }) { Text("নোটিফিকেশন অনুমতি") }
        Row {
            Text("বুটে wake rearm")
            Switch(checked = boot, onValueChange = {
                boot = it
                vm.setBootRearm(it)
            })
        }
        Button(onClick = { vm.scheduleProactiveNudge() }) { Text("proactive nudge") }
    }
}

/** ১৩ — user-owned PC relay */
@Composable
fun SendToPcScreen(vm: ZaraViewModel) {
    var text by remember { mutableStateOf("") }
    Column {
        Text("PC-তে পাঠাও", style = MaterialTheme.typography.headlineSmall)
        Text("শুধু তুমি দেওয়া relay endpoint; Maya gateway ব্যবহার হয় না।")
        OutlinedTextField(text, { text = it }, label = { Text("বার্তা") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = {
            if (text.isBlank()) return@Button
            val args = JSONObject().put("text", text)
            val step = JSONObject().put("tool", "send_to_pc").put("args", args)
            vm.startMission(JSONArray().put(step).toString())
            text = ""
        }) { Text("পাঠাও") }
    }
}
