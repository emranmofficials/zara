package com.zaraai.app.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * সম্পূর্ণ স্থানীয় মেমরি — কোনো ক্লাউড আপলোড নেই।
 * embedding মডেল বসালে score() overriding করা যায়; default keyword overlap।
 */
class MemoryStore(context: Context) {
    private val file = File(context.filesDir, "zara_memory.json")
    private val detailsFile = File(context.filesDir, "zara_details.json")

    /** embedding hook — null মানে keyword scoring। */
    var embedder: ((String) -> FloatArray)? = null

    fun remember(text: String, tag: String = "note") {
        val all = load()
        all.put(JSONObject().put("text", text).put("tag", tag)
            .put("at", System.currentTimeMillis()))
        while (all.length() > 500) all.remove(0)
        file.writeText(all.toString())
    }

    /** ইম্পোর্টের জন্য ব্যাচ লেখা — একবারে ফাইলে লেখে। */
    fun rememberAll(items: List<ImportedNote>) {
        if (items.isEmpty()) return
        val all = load()
        items.forEach {
            all.put(JSONObject()
                .put("text", it.text)
                .put("tag", it.tag.ifBlank { "note" })
                .put("at", if (it.at > 0) it.at else System.currentTimeMillis()))
        }
        while (all.length() > 500) all.remove(0)
        file.writeText(all.toString())
    }

    /** ব্যাকআপের জন্য সম্পূর্ণ মেমরি। */
    fun all(): JSONArray = load()

    fun recall(query: String, limit: Int = 3): List<String> {
        val all = load()
        return (0 until all.length())
            .map { all.getJSONObject(it) }
            .map { it.optString("text") to score(query, it.optString("text")) }
            .filter { it.second > 0f }
            .sortedByDescending { it.second }
            .take(limit)
            .map { it.first }
    }

    private fun score(query: String, text: String): Float {
        val e = embedder
        if (e != null) {
            val a = e(query); val b = e(text)
            var dot = 0f; var na = 0f; var nb = 0f
            for (i in 0 until minOf(a.size, b.size)) {
                dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
            }
            return if (na > 0 && nb > 0) dot / (kotlin.math.sqrt(na) * kotlin.math.sqrt(nb)) else 0f
        }
        val q = query.lowercase().split(Regex("\\W+")).filter { it.length > 2 }.toSet()
        val t = text.lowercase().split(Regex("\\W+")).toSet()
        return if (q.isEmpty()) 0f else q.intersect(t).size.toFloat() / q.size
    }

    // Maya-র memory-টুলের নিজস্ব সমতুল্য — সব কিছু শুধু এই ডিভাইসে।
    fun rememberFact(text: String) = remember(text, "fact")
    fun rememberDocument(text: String) = remember(text, "document")

    fun forgetMemory(text: String): Boolean {
        val all = load()
        val before = all.length()
        for (i in all.length() - 1 downTo 0) {
            if (all.optJSONObject(i)?.optString("text")?.contains(text, ignoreCase = true) == true)
                all.remove(i)
        }
        file.writeText(all.toString())
        return all.length() < before
    }

    fun setMyDetail(key: String, value: String) {
        val o = loadDetails(); o.put(key, value)
        detailsFile.writeText(o.toString())
    }

    fun myDetails(): JSONObject = loadDetails()

    private fun loadDetails(): JSONObject = runCatching {
        if (detailsFile.exists()) JSONObject(detailsFile.readText()) else JSONObject()
    }.getOrDefault(JSONObject())

    private fun load(): JSONArray = runCatching {
        if (file.exists()) JSONArray(file.readText()) else JSONArray()
    }.getOrDefault(JSONArray())
}
