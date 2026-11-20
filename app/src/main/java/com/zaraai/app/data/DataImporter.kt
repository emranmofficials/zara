package com.zaraai.app.data

import org.json.JSONArray
import org.json.JSONObject

/** ইম্পোর্ট করা এক নোট / এক বার্তা / সেটিংস — সব user-owned ডাটা। */
data class ImportedNote(val text: String, val tag: String = "note", val at: Long = 0L)
data class ImportedMessage(val role: String, val content: String)
data class ImportedData(
    val notes: List<ImportedNote> = emptyList(),
    val messages: List<ImportedMessage> = emptyList(),
    val settings: ZaraSettings? = null
) {
    val isEmpty: Boolean get() = notes.isEmpty() && messages.isEmpty() && settings == null
}

/**
 * ব্যবহারকারীর নিজে বেছে দেওয়া export ফাইল (JSON / CSV / plain text) পড়ে
 * ZaRa-র নিজস্ব store-এ মানচিত্র করে। কোনো অন্য অ্যাপের private storage পড়া হয় না,
 * কোনো নেটওয়ার্ক কল নেই, কোনো Maya সার্ভার/কী ব্যবহার হয় না।
 */
object DataImporter {

    fun parse(raw: String): ImportedData {
        val s = raw.trim()
        if (s.isEmpty()) return ImportedData()
        return when {
            s.startsWith("{") || s.startsWith("[") -> parseJson(s)
            else -> parseCsvOrText(s)
        }
    }

    // ---------- JSON ----------

    private fun parseJson(s: String): ImportedData = runCatching {
        when (val root = org.json.JSONTokener(s).nextValue()) {
            is JSONArray -> {
                val notes = mutableListOf<ImportedNote>()
                val msgs = mutableListOf<ImportedMessage>()
                collect(root, notes, msgs)
                ImportedData(notes, msgs)
            }
            is JSONObject -> parseObject(root)
            else -> ImportedData()
        }
    }.getOrDefault(ImportedData())

    private fun parseObject(o: JSONObject): ImportedData {
        val notes = mutableListOf<ImportedNote>()
        val msgs = mutableListOf<ImportedMessage>()

        for (k in NOTE_KEYS) o.optJSONArray(k)?.let { collect(it, notes, msgs) }
        for (k in MSG_KEYS) o.optJSONArray(k)?.let { collect(it, notes, msgs, forceMessage = true) }

        // কোনো array না থাকলে root-কেই একক আইটেম হিসেবে চেষ্টা করো
        if (notes.isEmpty() && msgs.isEmpty()) addItem(o, notes, msgs, force = false)

        return ImportedData(notes, msgs, settingsOf(o))
    }

    private fun collect(
        arr: JSONArray,
        notes: MutableList<ImportedNote>,
        msgs: MutableList<ImportedMessage>,
        forceMessage: Boolean = false
    ) {
        for (i in 0 until arr.length()) {
            when (val v = arr.get(i)) {
                is JSONObject -> addItem(v, notes, msgs, forceMessage)
                is JSONArray -> {
                    if (v.length() >= 2) {
                        val r = v.optString(0, "user") ?: "user"
                        val t = v.optString(1, null)
                        if (!t.isNullOrBlank()) msgs += ImportedMessage(role(r), t)
                    }
                }
                is String -> {
                    if (v.isNotBlank()) {
                        if (forceMessage) msgs += ImportedMessage("user", v)
                        else notes += ImportedNote(v)
                    }
                }
            }
        }
    }

    private fun addItem(
        o: JSONObject,
        notes: MutableList<ImportedNote>,
        msgs: MutableList<ImportedMessage>,
        force: Boolean
    ) {
        val text = s(o, "text", "content", "message", "note", "body", "value",
            "description", "reply", "query", "answer") ?: titleAndBody(o) ?: return
        val r = s(o, "role", "sender", "from", "speaker")
        if (r != null || force) msgs += ImportedMessage(role(r), text)
        else notes += ImportedNote(text, tagOf(o), l(o, "at", "timestamp", "createdAt", "date", "time"))
    }

    private fun titleAndBody(o: JSONObject): String? {
        val t = s(o, "title", "subject")
        val b = s(o, "body", "description")
        return when {
            t != null && b != null -> "$t: $b"
            t != null -> t
            else -> b
        }
    }

    // ---------- CSV / plain text ----------

    private fun parseCsvOrText(raw: String): ImportedData {
        val lines = raw.lineSequence().map { it.trimEnd('\r') }.filter { it.isNotBlank() }.toList()
        if (lines.isEmpty()) return ImportedData()

        val head = csvLine(lines.first()).map { it.trim().lowercase() }
        val textIdx = head.indexOfFirst { it in TEXT_COLS }
        if (textIdx < 0)
            return ImportedData(notes = lines.map { ImportedNote(it.trim()) })

        val roleIdx = head.indexOfFirst { it in ROLE_COLS }
        val tagIdx = head.indexOfFirst { it in TAG_COLS }
        val atIdx = head.indexOfFirst { it in AT_COLS }

        val notes = mutableListOf<ImportedNote>()
        val msgs = mutableListOf<ImportedMessage>()
        lines.drop(1).forEach { line ->
            val c = csvLine(line)
            val text = c.getOrNull(textIdx)?.trim()?.takeIf { it.isNotBlank() } ?: return@forEach
            val r = if (roleIdx >= 0) c.getOrNull(roleIdx)?.trim()?.takeIf { it.isNotBlank() } else null
            if (r != null) {
                msgs += ImportedMessage(role(r), text)
            } else {
                val tag = if (tagIdx >= 0) cleanTag(c.getOrNull(tagIdx) ?: "note") else "note"
                val at = if (atIdx >= 0) c.getOrNull(atIdx)?.trim()?.toLongOrNull() ?: 0L else 0L
                notes += ImportedNote(text, tag, at)
            }
        }
        return ImportedData(notes, msgs)
    }

    /** ছোট CSV reader — quotes ও comma-র ভেতরের comma সামলায়। */
    private fun csvLine(line: String): List<String> {
        val out = mutableListOf<String>()
        val sb = StringBuilder()
        var quoted = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' -> {
                    if (quoted && i + 1 < line.length && line[i + 1] == '"') {
                        sb.append('"'); i++
                    } else quoted = !quoted
                }
                c == ',' && !quoted -> { out += sb.toString(); sb.setLength(0) }
                else -> sb.append(c)
            }
            i++
        }
        out += sb.toString()
        return out
    }

    // ---------- settings ----------

    /** শুধু ওইসব কী আছে এমন export থেকেই সেটিংস আসে; না থাকলে keeping current values। */
    private fun settingsOf(o: JSONObject): ZaraSettings? {
        if (SETTING_KEYS.none { o.has(it) }) return null
        return ZaraSettings(
            apiKey = s(o, "apiKey", "api_key") ?: "",
            baseUrl = s(o, "baseUrl", "base_url") ?: "",
            model = s(o, "model") ?: "",
            sttModel = s(o, "sttModel", "stt_model") ?: "",
            voiceName = s(o, "voiceName", "voice_name") ?: "",
            speed = d(o, "speed", def = -1.0).toFloat(),
            pitch = d(o, "pitch", def = -1.0).toFloat(),
            speechMode = s(o, "speechMode", "speech_mode") ?: "",
            ttsModel = s(o, "ttsModel", "tts_model") ?: "",
            ttsVoice = s(o, "ttsVoice", "tts_voice") ?: ""
        )
    }

    // ---------- helpers ----------

    private fun s(o: JSONObject, vararg keys: String): String? {
        for (k in keys) {
            when (val v = o.opt(k)) {
                is String -> if (v.isNotBlank()) return v
                is Number -> return v.toString()
            }
        }
        return null
    }

    private fun d(o: JSONObject, vararg keys: String, def: Double): Double {
        for (k in keys) s(o, k)?.toDoubleOrNull()?.let { return it }
        return def
    }

    private fun l(o: JSONObject, vararg keys: String): Long {
        for (k in keys) s(o, k)?.let {
            return it.toLongOrNull() ?: it.toDoubleOrNull()?.toLong() ?: 0L
        }
        return 0L
    }

    private fun cleanTag(raw: String): String =
        raw.trim().lowercase().replace(Regex("[^a-z0-9_-]+"), "_").trim('_').take(24)
            .ifBlank { "note" }

    private fun tagOf(o: JSONObject): String =
        s(o, "tag", "label", "category", "type")?.let { cleanTag(it) } ?: "note"

    private fun role(raw: String?): String = when (raw?.trim()?.lowercase()) {
        "user", "human", "me", "you", "end_user", "ব্যবহারকারী" -> "user"
        "assistant", "ai", "bot", "model", "zara", "maya", "agent" -> "assistant"
        "system" -> "system"
        else -> "user"
    }

    /** ZaRa ব্যাকআপ — API key ইচ্ছেকৃতভাবে বাদ দেওয়া হয় (কখনো ফাইলে লেখা হয় না)। */
    fun buildExport(notes: JSONArray, messages: JSONArray, settings: ZaraSettings): JSONObject =
        JSONObject()
            .put("format", "zara-import-v1")
            .put("exportedAt", System.currentTimeMillis())
            .put("notes", notes)
            .put("messages", messages)
            .put("settings", JSONObject()
                .put("baseUrl", settings.baseUrl)
                .put("model", settings.model)
                .put("sttModel", settings.sttModel)
                .put("voiceName", settings.voiceName)
                .put("speed", settings.speed.toDouble())
                .put("pitch", settings.pitch.toDouble())
                .put("speechMode", settings.speechMode)
                .put("ttsModel", settings.ttsModel)
                .put("ttsVoice", settings.ttsVoice))

    private val NOTE_KEYS = arrayOf(
        "notes", "note", "memories", "memory", "items", "data", "records", "saved", "entries"
    )
    private val MSG_KEYS = arrayOf(
        "messages", "message", "chat", "chats", "history", "conversation",
        "conversations", "transcript", "dialog"
    )
    private val TEXT_COLS = setOf(
        "text", "content", "message", "note", "body", "value", "reply", "query"
    )
    private val ROLE_COLS = setOf("role", "sender", "from", "speaker")
    private val TAG_COLS = setOf("tag", "label", "category")
    private val AT_COLS = setOf("at", "timestamp", "createdat", "date", "time")
    private val SETTING_KEYS = arrayOf(
        "apiKey", "api_key", "baseUrl", "base_url", "model", "sttModel", "stt_model",
        "voiceName", "voice_name", "speed", "pitch", "speechMode", "speech_mode",
        "ttsModel", "tts_model", "ttsVoice", "tts_voice"
    )
}
