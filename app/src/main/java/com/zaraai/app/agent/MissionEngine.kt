package com.zaraai.app.agent

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Maya-র mission/chainer-এর নিজস্ব, সীমিত বাস্তবায়ন — ধাপগুলো শুধু fixed registry
 * থেকে আসে; প্রতি সংবেদনশীল ধাপে আলাদা অনুমতি, যেকোনো সময় বাতিল করা যায়।
 */
class MissionEngine(private val tools: ToolRegistry) {
    private var job: Job? = null

    @Volatile
    var active: Boolean = false
        private set

    @Volatile
    private var statusText: String = "কোনো মিশন চলছে না।"

    fun start(
        steps: List<Pair<String, JSONObject>>,
        onConfirm: suspend (String, JSONObject) -> Boolean
    ) {
        cancel()
        if (steps.isEmpty()) { statusText = "মিশনে কোনো ধাপ নেই।"; return }
        if (steps.size > 20) { statusText = "এক মিশনে ২০টার বেশি ধাপ চলবে না।"; return }

        active = true
        statusText = "মিশন শুরু — ${steps.size} ধাপ।"
        job = CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
            try {
                steps.forEachIndexed { i, (name, args) ->
                    if (!isActive) return@launch
                    statusText = "ধাপ ${i + 1}/${steps.size}: $name"
                    val def = tools.list().firstOrNull { it.name == name }
                    if (def == null) {
                        statusText = "$name নেই — মিশন বাতিল।"
                        return@launch
                    }
                    if (def.requiresConfirmation && !onConfirm(name, args)) {
                        statusText = "${i + 1} নম্বর ধাপে থামলাম — অনুমতি মেলনি।"
                        return@launch
                    }
                    val result = tools.call(name, args)
                    if (result.has("error")) {
                        statusText = "$name ব্যর্থ: ${result.optString("error")}"
                        return@launch
                    }
                    delay(200)
                }
                statusText = "মিশন শেষ — সব ${steps.size} ধাপ হয়েছে।"
            } finally {
                active = false
            }
        }
    }

    fun cancel() {
        job?.cancel()
        job = null
        active = false
        statusText = "মিশন বাতিল।"
    }

    fun status(): String = statusText
}
