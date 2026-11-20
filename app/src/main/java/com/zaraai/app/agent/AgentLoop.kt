package com.zaraai.app.agent

import com.zaraai.app.data.SpeechMode
import kotlinx.coroutines.isActive
import kotlin.coroutines.coroutineContext
import org.json.JSONArray
import org.json.JSONObject

/** Approved action awaiting the user's explicit yes/no. */
data class PendingConfirmation(val tool: String, val args: JSONObject)

class AgentLoop(
    private val model: ModelClient,
    private val tools: ToolRegistry,
    private val onConfirm: suspend (PendingConfirmation) -> Boolean,
    private val mode: SpeechMode = SpeechMode.PUNCHY
) {
    companion object { private const val TIMEOUT_MS = 180_000L }

    suspend fun run(userText: String, history: JSONArray): String {
        if (history.length() == 0)
            history.put(JSONObject().put("role", "system").put("content", ZaraPersona.system(mode)))

        if (StopWordDetector.isStop(userText)) return ZaraBehavior.STOPPED

        history.put(JSONObject().put("role", "user").put("content", userText))
        val started = System.currentTimeMillis()

        while (coroutineContext.isActive && System.currentTimeMillis() - started < TIMEOUT_MS) {
            val reply = model.chat(history)
            val call = parseToolCall(reply)
            if (call == null) {
                history.put(JSONObject().put("role", "assistant").put("content", reply))
                return ZaraBehavior.polish(reply)
            }
            val tool = call.getString("name")
            val args = call.optJSONObject("arguments") ?: JSONObject()
            val registered = tools.list().firstOrNull { it.name == tool }
            if (registered == null) {
                history.put(JSONObject().put("role", "user")
                    .put("content", "$tool নেই — অন্য রাস্তা দেখো।"))
                continue
            }
            if (registered.requiresConfirmation) {
                val ok = onConfirm(PendingConfirmation(tool, args))
                if (!ok) {
                    history.put(JSONObject().put("role", "user")
                        .put("content", "ব্যবহারকারী $tool চালাতে রাজি হননি।"))
                    continue
                }
            }
            val result = tools.call(tool, args)
            history.put(JSONObject().put("role", "user")
                .put("content", "$tool রেজাল্ট: $result"))
        }
        history.put(JSONObject().put("role", "user")
            .put("content", "টুল লুপ সময় শেষ; আর কিছু চালানো হয়নি।"))
        return if (coroutineContext.isActive) ZaraBehavior.TIMEOUT else ZaraBehavior.STOPPED
    }

    /** Expected model format: {"tool": "...", "arguments": {...}} or plain text. */
    private fun parseToolCall(text: String): JSONObject? = try {
        val obj = JSONObject(text)
        if (obj.has("tool") || obj.has("name"))
            obj.put("name", obj.optString("tool", obj.optString("name")))
        else null
    } catch (e: Exception) { null }
}
