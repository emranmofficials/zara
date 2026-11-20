package com.zaraai.app.agent

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Fixed, app-owned tool registry. No server-pushed code, no shell execution. */
class ToolRegistry {
    private val tools = linkedMapOf<String, Tool>()
    private val recent = ArrayDeque<Triple<String, Long, Boolean>>()

    init {
        register(Tool("get_time", "Current local date and time", false) {
            JSONObject().put("time", SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date()))
        })
        // আসল ব্যাটারি AutomationTools থেকে register হয়; এটা শুধু fallback
        register(Tool("get_battery", "Battery level of this device", false) {
            JSONObject().put("note", "platform hook এখনো বসানো হয়নি")
        })
    }

    fun register(tool: Tool) { tools[tool.name] = tool }
    fun list() = tools.values.toList()

    suspend fun call(name: String, args: JSONObject): JSONObject {
        val started = System.currentTimeMillis()
        val result = tools[name]?.run?.invoke(args)
            ?: JSONObject().put("error", "unknown tool: $name")
        synchronized(recent) {
            recent.addLast(Triple(name, System.currentTimeMillis() - started, !result.has("error")))
            while (recent.size > 30) recent.removeFirst()
        }
        // একই টুল একই আর্গুমেন্টে বারবার ডাকা হলে dedupe ইঙ্গিত
        val last = synchronized(recent) { recent.lastOrNull()?.first }
        if (last == name && recent.size >= 2 &&
            synchronized(recent) { recent[recent.size - 2].first } == name
        ) result.put("_dedupe_hint", "এই টুলটা সম্প্রতি চলেছে — আগের ফল ব্যবহার করো।")
        return result
    }

    /** latency/success log — শুধু ডিভাইসে, কোথাও আপলোড হয় না। */
    fun stats(): JSONArray = synchronized(recent) {
        JSONArray().also { arr ->
            recent.forEach { (name, ms, ok) ->
                arr.put(JSONObject().put("tool", name).put("ms", ms).put("ok", ok))
            }
        }
    }
}
