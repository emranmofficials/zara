package com.zaraai.app.ui

import android.app.Application
import android.content.Intent
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.zaraai.app.agent.AgentLoop
import com.zaraai.app.agent.ConsentManager
import com.zaraai.app.agent.IntentRouter
import com.zaraai.app.agent.MissionEngine
import com.zaraai.app.agent.ModelClient
import com.zaraai.app.agent.NoticeWorker
import com.zaraai.app.agent.OAuthState
import com.zaraai.app.agent.ProactiveWorker
import com.zaraai.app.agent.ModeManager
import com.zaraai.app.agent.PendingConfirmation
import com.zaraai.app.agent.RestartGuard
import com.zaraai.app.agent.SkillEngine
import com.zaraai.app.agent.ToolRegistry
import com.zaraai.app.agent.TurnTakingGate
import com.zaraai.app.agent.VoiceGuardian
import com.zaraai.app.agent.ZaraBehavior
import com.zaraai.app.agent.buildAccessibilityTools
import com.zaraai.app.agent.buildAutomationTools
import com.zaraai.app.agent.buildCameraTools
import com.zaraai.app.agent.buildConnectorTools
import com.zaraai.app.agent.buildContactTools
import com.zaraai.app.agent.buildResearchTools
import com.zaraai.app.agent.buildSystemTools
import com.zaraai.app.data.ChatHistoryStore
import com.zaraai.app.data.DataImporter
import com.zaraai.app.data.MemoryStore
import com.zaraai.app.data.Settings
import com.zaraai.app.data.SpeechMode
import com.zaraai.app.data.VoiceProfile
import com.zaraai.app.data.ZaraSettings
import com.zaraai.app.diag.ZaraDiagnostics
import com.zaraai.app.voice.ApiSttEngine
import com.zaraai.app.voice.MediaProjectionGate
import com.zaraai.app.voice.SystemSttEngine
import com.zaraai.app.voice.TtsConfig
import com.zaraai.app.voice.TtsEngine
import com.zaraai.app.voice.VoiceSession
import com.zaraai.app.voice.WakeWordDetector
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class UiState(
    val status: String = ZaraBehavior.READY,
    val listening: Boolean = false,
    val transcript: String = "",
    val reply: String = "",
    val settings: ZaraSettings = ZaraSettings(),
    val confirmation: PendingConfirmation? = null
)

class ZaraViewModel(app: Application) : AndroidViewModel(app) {
    private val appContext: Application = app
    private val _ui = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = _ui
    private val settingsRepo = Settings(app)
    private val tts = TtsEngine(app)
    private val tools = ToolRegistry()
    private val consent = ConsentManager()
    private val guardian = VoiceGuardian()
    private val memory = MemoryStore(app)
    private val historyStore = ChatHistoryStore(app)
    private val skills = SkillEngine(tools, File(app.filesDir, "zara_skills.json"))
    private val missions = MissionEngine(tools)
    private val systemStt = SystemSttEngine(app)
    private val screenGate = MediaProjectionGate(app)
    private val history = JSONArray()
    private val wake = WakeWordDetector()
    private var pendingConfirm: CompletableDeferred<Boolean>? = null
    private var activeJob: Job? = null
    private var secureGate: ((() -> Unit) -> Unit)? = null

    /** MainActivity Android-র BiometricPrompt gate বসায়। */
    fun attachSecureGate(gate: (approved: () -> Unit) -> Unit) { secureGate = gate }

    /** মানুষের-মতো কন্ঠ (neural TTS) বা on-device/fallback — সব কনফিগারেশন এখানে। */
    private fun configureTts(s: ZaraSettings) {
        tts.configure(
            TtsConfig(
                apiKey = s.apiKey,
                baseUrl = s.baseUrl,
                ttsModel = s.ttsModel,
                ttsVoice = s.ttsVoice,
                profile = VoiceProfile(s.voiceName, s.speed, s.pitch)
            )
        )
    }

    init {
        val savedHistory = historyStore.load()
        for (i in 0 until savedHistory.length()) {
            savedHistory.optJSONObject(i)?.let { history.put(it) }
        }
        if (!RestartGuard(app).allow()) {
            _ui.value = _ui.value.copy(status = "অনেকবার রিস্টার্ট হয়েছে — একটু পরে চালাও")
        } else {
            setup()
        }
    }

    private fun setup() {
        Log.d("ZaRaInit", "setup start")
        runCatching {
            buildAutomationTools(appContext, consent, memory).forEach { tools.register(it) }
            buildSystemTools(appContext, consent, guardian).forEach { tools.register(it) }
            buildAccessibilityTools(consent, guardian).forEach { tools.register(it) }
            buildCameraTools(appContext, consent, guardian).forEach { tools.register(it) }
            buildContactTools(appContext, consent, guardian).forEach { tools.register(it) }
            buildConnectorTools({ _ui.value.settings }).forEach { tools.register(it) }
            buildResearchTools(appContext, { _ui.value.settings }).forEach { tools.register(it) }
            viewModelScope.launch {
                val saved = settingsRepo.flow.first()
                _ui.value = _ui.value.copy(settings = saved)
                configureTts(saved)
                VoiceSession.state.collect { st ->
                    _ui.value = _ui.value.copy(listening = st.listening, status = st.status)
                }
            }
            VoiceSession.onUtterance = { pcm -> onUtterance(pcm) }
            VoiceSession.onBargeIn = { bargeIn() }
        }.onFailure {
            Log.e("ZaRaInit", "setup failed", it)
            ZaraDiagnostics.log("START", "setup failed", it)
        }
        Log.d("ZaRaInit", "setup done")
    }

    fun saveSettings(s: ZaraSettings) = viewModelScope.launch {
        settingsRepo.save(s)
        configureTts(s)
        _ui.value = _ui.value.copy(settings = s)
    }

    /** কথা বলার মোড বদলালেই গতি/স্বরও সেই মোডে চলে যায়। */
    fun setMode(mode: SpeechMode) = viewModelScope.launch {
        val next = _ui.value.settings.copy(
            speechMode = mode.name, speed = mode.rate, pitch = mode.pitch
        )
        settingsRepo.save(next)
        configureTts(next)
        _ui.value = _ui.value.copy(settings = next)
        tts.speak("${mode.label} মোড। " + ZaraBehavior.greeting())
    }

    /** বর্তমান কন্ঠে এক লাইন বলে শুনে দেখো। */
    fun previewVoice() {
        tts.speak(ZaraBehavior.greeting())
    }

    /** কী ছাড়া সিস্টেম STT — API key না থাকলেও কথা বুঝতে পারে। */
    fun onSystemStt() = viewModelScope.launch {
        cancelActive()
        try {
            VoiceSession.update(status = "শোনছি…")
            val text = systemStt.listen()
            if (text.isBlank()) speak(ZaraBehavior.NO_SPEECH)
            else handleText(text)
        } catch (e: Exception) {
            speak(ZaraBehavior.error(e.message))
        }
    }

    /** Android-র নিজস্ব consent dialog — কোনো গোপন ক্যাপচার নয়। */
    fun screenConsentIntent() = screenGate.consentIntent()
    fun grantScreen(resultCode: Int, data: Intent) = screenGate.grant(resultCode, data)
    fun stopScreen() = screenGate.stop()
    val screenActive: Boolean get() = screenGate.active

    /** নতুন কথা এলে আগের কাজ আর কন্ঠ কেটে দাও — Maya-র মতো barge-in। */
    fun onUtterance(pcm: ShortArray) {
        cancelActive()
        activeJob = viewModelScope.launch {
            val s = _ui.value.settings
            if (s.apiKey.isBlank()) {
                speak(ZaraBehavior.NEED_KEY)
                return@launch
            }
            try {
                VoiceSession.update(status = ZaraBehavior.THINKING)
                val text = ApiSttEngine(s.baseUrl, s.apiKey, s.sttModel).transcribe(pcm)
                if (text.isBlank()) {
                    speak(ZaraBehavior.NO_SPEECH)
                    return@launch
                }
                handleText(text)
            } catch (e: Exception) {
                speak(ZaraBehavior.error(e.message))
            }
        }
    }

    /** বাংলা টেক্সট ইনপুট — API key ছাড়া persona টেস্ট করার সুবিধা। */
    fun onText(input: String) {
        cancelActive()
        activeJob = viewModelScope.launch { handleText(input) }
    }

    /** fast-path ও স্কিল/মিশনের জন্য একই confirmation + biometric + রোল গেট। */
    private suspend fun askConfirmation(tool: String, args: JSONObject): Boolean {
        val deferred = CompletableDeferred<Boolean>()
        pendingConfirm = deferred
        _ui.value = _ui.value.copy(confirmation = PendingConfirmation(tool, args))
        val approved = deferred.await()
        pendingConfirm = null
        _ui.value = _ui.value.copy(confirmation = null)
        val allowed = approved && guardian.allows(tool)
        if (allowed) consent.grant(tool)
        return allowed
    }

    private suspend fun confirmAndRun(tool: String, args: JSONObject): String? {
        val def = tools.list().firstOrNull { it.name == tool } ?: return null
        if (def.requiresConfirmation && !askConfirmation(tool, args)) return ZaraBehavior.DECLINED
        val result = tools.call(tool, args)
        return if (result.has("error")) result.optString("error") else ZaraBehavior.toolDone(tool)
    }

    private fun subject(text: String, vararg markers: String): String {
        var s = text
        markers.forEach { m ->
            val i = s.lowercase().indexOf(m)
            if (i >= 0) s = s.substring(i + m.length)
        }
        return s.trim(' ', '।', '.', ',')
    }

    private suspend fun handleText(input: String) {
        val command = wake.matches(input)
        val text = command ?: input.trim()
        if (command != null) VoiceSession.update(status = ZaraBehavior.WAKE_ACK)
        if (text.isBlank()) {
            speak(ZaraBehavior.NO_SPEECH)
            return
        }
        _ui.value = _ui.value.copy(transcript = text, reply = "")
        VoiceSession.update(status = ZaraBehavior.THINKING)

        // দ্রুত, নির্ভরযোগ্য উত্তর আগে — মডেল না থাকলেও ZaRa নীরব থাকবে না
        ZaraBehavior.localReply(text, tools)?.let { speak(it); return }

        // মডেল না ডাকেই নিরাপদ কাজ — Maya-র fast-path-এর নিজস্ব বাংলা বাস্তবায়ন
        val routed = IntentRouter.match(text)
        if (routed != null) {
            val args = routed.args
            when (routed.tool) {
                "add_note" -> args.put("text", subject(text, "নোট মনে রাখ", "মনে রাখবি", "remember that"))
                "open_app" -> args.put("name", subject(text, "অ্যাপ খোল", "open app"))
                "search_web" -> args.put("query", subject(text, "খুঁজ", "search web", "web search"))
            }
            confirmAndRun(routed.tool, args)?.let { speak(it); return }
        }

        val s = _ui.value.settings
        if (s.apiKey.isBlank()) { speak(ZaraBehavior.NEED_KEY); return }
        try {
            val loop = AgentLoop(
                model = ModelClient(s.baseUrl, s.apiKey, s.model),
                tools = tools,
                mode = SpeechMode.from(s.speechMode),
                onConfirm = { pending -> askConfirmation(pending.tool, pending.args) }
            )
            speak(loop.run(text, history))
            historyStore.save(history)
        } catch (e: Exception) {
            speak(ZaraBehavior.error(e.message))
        } finally {
            pendingConfirm = null
            _ui.value = _ui.value.copy(confirmation = null)
        }
    }

    /** সবসময় ZaRa-র ধরণে, turn-taking মেনে কথা বলে। */
    private suspend fun speak(reply: String) {
        val polished = ZaraBehavior.polish(reply)
        if (!ModeManager.allowSpeech()) {
            _ui.value = _ui.value.copy(reply = polished, status = "নীরব মোড — কন্ঠ বন্ধ")
            return
        }
        val st = VoiceSession.state.value
        val decision = TurnTakingGate.decide(
            userIsSpeaking = st.listening && st.userSpeaking,
            partialTranscriptReady = true,
            toolRunning = false
        )
        _ui.value = _ui.value.copy(reply = polished)
        when (decision) {
            TurnTakingGate.Decision.SUPPRESS -> VoiceSession.update(status = "থামলাম")
            TurnTakingGate.Decision.DEFER ->
                VoiceSession.update(status = "তুমি শেষ হলে বলি — শুনছি")
            TurnTakingGate.Decision.SPEAK -> {
                VoiceSession.update(status = ZaraBehavior.READY)
                runCatching { tts.speak(polished) }
                    .onFailure { ZaraDiagnostics.log("TTS", "VM speak threw", it) }
                if (tts.cloudKeyInvalid)
                    _ui.value = _ui.value.copy(
                        status = "API key কাজ করছে না — সিস্টেম কন্ঠে চলছি। সেটিংসে key ঠিক করো।"
                    )
            }
        }
    }

    private fun cancelActive() {
        activeJob?.cancel()
        activeJob = null
        if (tts.isSpeaking) tts.stop()
    }

    /** ব্যবহারকারী ZaRa-র কথার মাঝে কথা বললে — কাজ আর কন্ঠ দুটোই থামে। */
    fun bargeIn() {
        cancelActive()
        consent.revokeAll()
        pendingConfirm?.complete(false)
        pendingConfirm = null
        _ui.value = _ui.value.copy(reply = "", confirmation = null)
        VoiceSession.update(status = ZaraBehavior.STOPPED)
    }

    /** UI-র "হ্যাঁ" — আগে unlock যাচাই, তারপর টুল চালানো। */
    fun approveConfirmation() {
        val approve = { resolveConfirmation(true) }
        val gate = secureGate
        if (gate == null) approve() else gate(approve)
    }

    fun denyConfirmation() = resolveConfirmation(false)

    fun resolveConfirmation(approved: Boolean) {
        pendingConfirm?.complete(approved)
        pendingConfirm = null
        _ui.value = _ui.value.copy(confirmation = null)
    }

    // ---- Maya-র বাকি ফিচারের নিজস্ব, স্থানীয় সমতুল্য ----

    /** ঘুম / ড্রাইভিং / নীরব / স্বাভাবিক — কখন কন্ঠ বের হবে ঠিক করে। */
    fun setDeviceMode(mode: ModeManager.Mode) {
        ModeManager.set(mode)
        tts.speak("${mode.label} মোড।")
    }

    /** মালিক / বন্ধু / অতিথি / ব্লক — রোল অনুযায়ী টুল সীমা। */
    fun setRole(role: VoiceGuardian.Role) {
        guardian.setRole(role)
        tts.speak("${role.label} রোল।")
    }

    /** শুধু ডিভাইসে থাকা, ব্যবহারকারী লেখা স্কিল — কোনো সার্ভার পুশ নয়। */
    fun installSkill(json: String) = viewModelScope.launch { speak(skills.install(json)) }
    fun listSkills() = viewModelScope.launch { speak(skills.list()) }
    fun removeSkill(name: String) = viewModelScope.launch { speak(skills.remove(name)) }

    fun runSkill(name: String) = viewModelScope.launch {
        speak(skills.run(name) { t, a -> askConfirmation(t, a) })
    }

    /** ধাপে ধাপে মিশন — প্রতি সংবেদনশীল ধাপে আলাদা অনুমতি। */
    fun startMission(json: String) = viewModelScope.launch {
        val arr = try { JSONArray(json) } catch (e: Exception) {
            speak("মিশনের JSON ঠিক নয়।")
            return@launch
        }
        val steps = (0 until arr.length()).mapNotNull { i ->
            val o = arr.optJSONObject(i) ?: return@mapNotNull null
            val tool = o.optString("tool")
            if (tool.isBlank()) null else tool to (o.optJSONObject("args") ?: JSONObject())
        }
        missions.start(steps) { t, a -> askConfirmation(t, a) }
        speak(missions.status())
    }

    fun missionStatus() = viewModelScope.launch { speak(missions.status()) }
    fun cancelMission() { missions.cancel(); VoiceSession.update(status = "মিশন বাতিল") }

    /** টুল latency/success log — শুধু ডিভাইসে। */
    fun toolStats(): JSONArray = tools.stats()

    /** ব্যবহারকারীর নিজস্ব ব্যাকআপ — API key কখনো ফাইলে লেখা হয় না। */
    fun exportData(): String =
        DataImporter.buildExport(historyStore.load(), JSONArray(), _ui.value.settings).toString()

    fun historySize(): Int = historyStore.load().length()

    /** ব্যবহারকারী বেছে দেওয়া JSON/CSV/text — অন্য অ্যাপের ডাটা পড়া হয় না। */
    fun importData(raw: String) = viewModelScope.launch {
        val data = DataImporter.parse(raw)
        if (data.isEmpty) {
            speak("এই ফাইলে কিছু পাওয়া গেলো না।")
            return@launch
        }
        memory.rememberAll(data.notes)
        data.messages.forEach {
            history.put(JSONObject().put("role", it.role).put("content", it.content))
        }
        historyStore.save(history)
        data.settings?.let { imported ->
            val current = _ui.value.settings
            val next = current.copy(
                baseUrl = imported.baseUrl.ifBlank { current.baseUrl },
                model = imported.model.ifBlank { current.model },
                sttModel = imported.sttModel.ifBlank { current.sttModel },
                voiceName = imported.voiceName.ifBlank { current.voiceName },
                ttsModel = imported.ttsModel.ifBlank { current.ttsModel },
                ttsVoice = imported.ttsVoice.ifBlank { current.ttsVoice }
            )
            settingsRepo.save(next)
            configureTts(next)
            _ui.value = _ui.value.copy(settings = next)
        }
        speak("${data.notes.size} নোট ও ${data.messages.size} বার্তা আমদানি করা হয়েছে।")
    }

    fun clearHistory() = viewModelScope.launch {
        historyStore.clear()
        speak("কথোপকথনের ইতিহাস মুছে ফেলা হয়েছে।")
    }

    /** বুটে wake rearm চাই কি না — ব্যবহারকারীর স্পষ্ট পছন্দ। */
    fun setBootRearm(enabled: Boolean) {
        appContext.getSharedPreferences("zara_boot", Application.MODE_PRIVATE)
            .edit().putBoolean("rearm", enabled).apply()
    }

    fun bootRearmEnabled(): Boolean =
        appContext.getSharedPreferences("zara_boot", Application.MODE_PRIVATE)
            .getBoolean("rearm", false)

    /** নিজস্ব OAuth connector-এর জন্য PKCE state — client ID ব্যবহারকারীর। */
    fun oauthBegin(): String = OAuthState.begin().state
    fun oauthValidate(state: String): Boolean = OAuthState.validate(state)

    fun scheduleProactiveNudge() {
        WorkManager.getInstance(appContext).enqueue(OneTimeWorkRequestBuilder<ProactiveWorker>().build())
    }

    fun showNotice(text: String) {
        val data = Data.Builder().putString("text", text).build()
        WorkManager.getInstance(appContext).enqueue(
            OneTimeWorkRequestBuilder<NoticeWorker>().setInputData(data).build()
        )
    }

    override fun onCleared() {
        cancelActive()
        missions.cancel()
        consent.revokeAll()
        stopScreen()
        pendingConfirm?.complete(false)
        VoiceSession.onUtterance = null
        VoiceSession.onBargeIn = null
        tts.shutdown()
        super.onCleared()
    }
}
