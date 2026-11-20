package com.zaraai.app.agent

import android.content.Context
import com.zaraai.app.data.ZaraSettings
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Maya-র deep-research / coding ফ্লোর নিজস্ব, shell-মুক্ত সমতুল্য।
 * search শুধু ব্যবহারকারীর দেওয়া https endpoint; summary শুধু ব্যবহারকারীর নিজস্ব LLM key।
 * ফাইল শুধু app-এর নিজস্ব sandbox-এ — কোনো shell, deploy বা PATH বাইরে লেখা নেই।
 */
fun buildResearchTools(context: Context, settings: () -> ZaraSettings): List<Tool> {
    val workDir = File(context.filesDir, "zara_work").apply { mkdirs() }
    val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS).readTimeout(20, TimeUnit.SECONDS).build()

    fun fetch(template: String, query: String, key: String): String {
        val q = java.net.URLEncoder.encode(query, "UTF-8")
        val url = template.replace("{q}", q).replace("{query}", q).replace("{key}", key)
        if (!url.startsWith("https://", ignoreCase = true))
            throw IllegalArgumentException("শুধু https:// search endpoint অনুমোদিত।")
        val req = Request.Builder().url(url)
            .also { if (key.isNotBlank()) it.header("Authorization", "Bearer $key") }
            .build()
        return client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IllegalStateException("search HTTP ${r.code}")
            r.body?.string().orEmpty().take(4000)
        }
    }

    fun safeFile(name: String): File? {
        if (name.isBlank() || name.contains('/') || name.contains('\\') || name.contains("..")) return null
        if (!name.matches(Regex("[A-Za-z0-9_.-]{1,80}"))) return null
        return File(workDir, name)
    }

    return listOf(
        Tool("deep_research", "নিজস্ব search + LLM দিয়ে বাংলা সংক্ষেপ তৈরি করে", false) { a ->
            val s = settings()
            val query = a.optString("query", a.optString("text", ""))
            if (query.isBlank()) return@Tool JSONObject().put("error", "কী খুঁজবো?")
            val cfg = runCatching { JSONObject(s.connectorsJson) }.getOrDefault(JSONObject())
            val template = cfg.optString("search", "")
            if (template.isBlank())
                return@Tool JSONObject().put("error", "সেটিংসে নিজস্ব search endpoint দাও।")
            try {
                val raw = fetch(template, query, cfg.optString("key", ""))
                if (s.apiKey.isBlank())
                    return@Tool JSONObject().put("ok", true).put("summary", raw.take(1200))
                        .put("note", "LLM key না থাকায় কাঁচা ফল দেখানো হলো।")
                val prompt =
                    "ব্যবহারকারীর প্রশ্ন: $query\n\nউৎস:\n${raw.take(3000)}\n\nউত্তর সংক্ষেপে বাংলায় দাও।"
                val messages = JSONArray().put(
                    JSONObject().put("role", "user").put("content", prompt)
                )
                val summary = ModelClient(s.baseUrl, s.apiKey, s.model).chat(messages)
                JSONObject().put("ok", true).put("summary", summary)
            } catch (e: Exception) {
                JSONObject().put("error", "research ব্যর্থ: ${e.message}")
            }
        },
        Tool("write_work_file", "app-এর নিজস্ব কাজের ফোল্ডারে ফাইল লেখে", true) { a ->
            val file = safeFile(a.optString("name"))
                ?: return@Tool JSONObject().put("error", "ফাইলের নাম ঠিক নয়।")
            if (!guardWrite(context)) return@Tool JSONObject().put("error", "লেখার অনুমতি নেই।")
            file.writeText(a.optString("content").take(100_000))
            JSONObject().put("ok", true).put("path", file.name)
        },
        Tool("read_work_file", "নিজস্ব কাজের ফোল্ডারের ফাইল পড়ে", false) { a ->
            val file = safeFile(a.optString("name"))
                ?: return@Tool JSONObject().put("error", "ফাইলের নাম ঠিক নয়।")
            if (!file.exists()) return@Tool JSONObject().put("error", "ফাইল নেই।")
            JSONObject().put("ok", true).put("content", file.readText().take(20_000))
        },
        Tool("list_work_files", "নিজস্ব কাজের ফোল্ডারের ফাইল দেখায়", false) {
            val names = JSONArray()
            workDir.listFiles()?.filter { it.isFile }?.forEach { names.put(it.name) }
            JSONObject().put("ok", true).put("files", names)
        }
    )
}

private fun guardWrite(context: Context): Boolean =
    context.getSharedPreferences("zara_boot", Context.MODE_PRIVATE)
        .getBoolean("allow_work_files", true)
