package com.zaraai.app.agent

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * শুধু ডিভাইসে থাকা, ব্যবহারকারীর নিজে লেখা স্কিল/ম্যাক্রো — কোনো সার্ভার-পুশড
 * টুল বান্ডেল নয়, কোনো shell স্টেপ নয়। ইনস্টলের সময়ই ধাপগুলোর নাম fixed registry
 * দিয়ে যাচাই করা হয়; অজানা বা নিষিদ্ধ ধাপ থাকলে পুরো স্কিল বাতিল।
 */
class SkillEngine(private val tools: ToolRegistry, private val file: File) {
    data class Step(val tool: String, val args: JSONObject)
    data class Skill(val name: String, val intent: String, val steps: List<Step>)

    private var skills: List<Skill> = load()

    fun install(json: String): String {
        val obj = try { JSONObject(json) } catch (e: Exception) { return "স্কিল বাতিল: JSON ঠিক নয়।" }
        val name = obj.optString("name").trim().lowercase()
        if (name.isBlank()) return "স্কিল বাতিল: নাম দাও।"

        val rawSteps = try { JSONArray(obj.optString("steps", "[]")) }
                       catch (e: Exception) { return "স্কিল বাতিল: ধাপগুলো ঠিক নয়।" }
        if (rawSteps.length() == 0 || rawSteps.length() > 20)
            return "স্কিল বাতিল: ১–২০ ধাপ দিতে হবে।"

        val parsed = mutableListOf<Step>()
        for (i in 0 until rawSteps.length()) {
            val s = rawSteps.optJSONObject(i) ?: return "স্কিল বাতিল: ধাপ ${i + 1} অকার্যকর।"
            val tool = s.optString("tool").lowercase()
            if (tool in FORBIDDEN) return "স্কিল বাতিল: '$tool' নিষিদ্ধ।"
            if (tools.list().none { it.name == tool })
                return "স্কিল বাতিল: '$tool' registry-তে নেই।"
            parsed.add(Step(tool, s.optJSONObject("args") ?: JSONObject()))
        }

        val skill = Skill(name, obj.optString("intent", name), parsed)
        skills = skills.filterNot { it.name == name } + skill
        save()
        return "স্কিল '$name' যোগ হয়েছে — ${parsed.size} ধাপ।"
    }

    fun remove(name: String): String {
        val n = name.trim().lowercase()
        val before = skills.size
        skills = skills.filterNot { it.name == n }
        save()
        return if (skills.size < before) "স্কিল '$n' বাদ দিলাম।" else "স্কিল '$n' পাওয়া গেলো না।"
    }

    fun list(): String =
        if (skills.isEmpty()) "কোনো স্কিল নেই। নিজে একটা যোগ করো।"
        else skills.joinToString("\n") { "• ${it.name} — ${it.steps.size} ধাপ (${it.intent})" }

    suspend fun run(name: String, onConfirm: suspend (String, JSONObject) -> Boolean): String {
        val s = skills.firstOrNull { it.name == name.trim().lowercase() }
            ?: return "স্কিল '$name' নেই। '$name' স্কিল তৈরি করে নাও।"
        val log = StringBuilder()
        for ((i, step) in s.steps.withIndex()) {
            val def = tools.list().firstOrNull { it.name == step.tool }
                ?: return "${step.tool} ধাপে থামলাম — টুল নেই।"
            if (def.requiresConfirmation && !onConfirm(step.tool, step.args))
                return "${i + 1} নম্বর ধাপে থামলাম — অনুমতি মেলনি।"
            val result = tools.call(step.tool, step.args)
            if (result.has("error"))
                return "${step.tool} ব্যর্থ: ${result.optString("error")}"
            log.append(step.tool).append(" ✓; ")
        }
        return "স্কিল '${s.name}' শেষ। $log"
    }

    fun find(intentText: String): Skill? {
        val t = intentText.trim().lowercase()
        return skills.firstOrNull { t.contains(it.name) || t.contains(it.intent.lowercase()) }
    }

    private fun load(): List<Skill> = runCatching {
        if (!file.exists()) emptyList()
        else {
            val arr = JSONArray(file.readText())
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                val steps = JSONArray(o.optString("steps", "[]"))
                Skill(
                    o.optString("name"),
                    o.optString("intent", o.optString("name")),
                    (0 until steps.length()).mapNotNull { j ->
                        val st = steps.optJSONObject(j) ?: return@mapNotNull null
                        Step(st.optString("tool"), st.optJSONObject("args") ?: JSONObject())
                    }
                )
            }
        }
    }.getOrDefault(emptyList())

    private fun save() {
        val arr = JSONArray()
        skills.forEach { s ->
            val steps = JSONArray()
            s.steps.forEach { steps.put(JSONObject().put("tool", it.tool).put("args", it.args)) }
            arr.put(JSONObject().put("name", s.name).put("intent", s.intent).put("steps", steps))
        }
        file.writeText(arr.toString())
    }

    companion object {
        private val FORBIDDEN = setOf(
            "termux_run", "run_shell", "bash", "wipe_device", "factory_reset", "run_tool_bundle"
        )
    }
}
