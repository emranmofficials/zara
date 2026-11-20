package com.zaraai.app.data

import android.content.Context
import org.json.JSONArray
import java.io.File

/** কথোপকথনের ইতিহাস সম্পূর্ণ স্থানীয় — কোনো ক্লাউড সিঙ্ক নেই। */
class ChatHistoryStore(context: Context) {
    private val file = File(context.filesDir, "zara_history.json")

    fun load(): JSONArray = runCatching {
        if (file.exists()) JSONArray(file.readText()) else JSONArray()
    }.getOrDefault(JSONArray())

    fun save(history: JSONArray) {
        while (history.length() > MAX) history.remove(0)
        file.writeText(history.toString())
    }

    fun clear() { file.runCatching { delete() } }

    companion object { private const val MAX = 400 }
}
