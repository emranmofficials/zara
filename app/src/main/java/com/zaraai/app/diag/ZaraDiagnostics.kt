package com.zaraai.app.diag

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ZaRa-র নিজস্ব ডায়াগনস্টিকস — সব ইভেন্ট ডিভাইসেই থাকে, কোথাও পাঠানো হয় না।
 * রিপোর্টটা Download/ZaRa_Diagnostics.txt-এ লেখা হয়, তাই ডেভেলপার সরাসরি পড়তে পারে
 * এবং ব্যবহারকারী চাইলে শেয়ারও করতে পারে। কোনো নেটওয়ার্ক/টেলিমেট্রি নেই।
 */
object ZaraDiagnostics {
    private data class Event(
        val time: String,
        val level: String,
        val tag: String,
        val message: String,
        val stack: String?
    )

    private val events = ArrayDeque<Event>()
    private val counts = mutableMapOf<String, Int>()
    @Volatile private var appContext: Context? = null
    private val fmt = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private const val MAX = 250
    private const val FILE_NAME = "ZaRa_Diagnostics.txt"

    @Synchronized
    fun log(tag: String, message: String, error: Throwable? = null, level: String? = null) {
        val lv = level ?: if (error != null) "ERROR" else "INFO"
        val stack = error?.let { runCatching { android.util.Log.getStackTraceString(it) }.getOrNull() }
        events.addLast(Event(fmt.format(Date()), lv, tag, message.take(1200), stack?.take(4000)))
        while (events.size > MAX) events.removeFirst()
        val key = "$tag|$lv|${message.take(120)}"
        counts[key] = (counts[key] ?: 0) + 1
        if (lv == "ERROR" || lv == "FATAL") {
            android.util.Log.e("ZaRaDiag", "$tag: $message", error)
            appContext?.let { ctx -> runCatching { flush(ctx) } }
        }
    }

    fun mark(stage: String) = log("FLOW", stage)

    /** কোন ইভেন্ট বারবার ঘটছে — সেটা থেকে IMPROVE পরামর্শ তৈরি করে। */
    @Synchronized
    fun report(): String = buildString {
        appendLine("ZaRa Diagnostics — ${fmt.format(Date())}")
        appendLine("events=${events.size} · package=com.zaraai.app")
        appendLine("──────────────────────────────")
        events.forEach { e ->
            appendLine("${e.time} [${e.level}] ${e.tag}: ${e.message}")
            e.stack?.let { appendLine(it) }
        }
        appendLine("──────────────────────────────")
        appendLine("FREQUENT ISSUES")
        counts.filter { it.key.contains("|ERROR|") || it.key.contains("|FATAL|") }
            .toList().sortedByDescending { it.second }.take(12).forEach { (k, n) ->
                appendLine("$n× $k")
            }
        appendLine("──────────────────────────────")
        appendLine("IMPROVEMENTS")
        val hints = mutableSetOf<String>()
        events.forEach { e ->
            when {
                e.message.contains("401", true) || e.message.contains("API key", true) ->
                    hints += "API KEY: সেটিংসে key/baseUrl ঠিক করো। বাতিল key-এ neural TTS বন্ধ, system TTS চলবে।"
                e.tag.contains("TTS", true) -> hints += "TTS: নিজস্ব bn-BD voice/key যাচাই করো; fallback system TTS রাখো।"
                e.tag.contains("STT", true) -> hints += "STT: মাইক অনুমতি ও bn-BD ইনপুট যাচাই করো।"
                e.tag.contains("TOOL", true) -> hints += "TOOL: টুল আর্গুমেন্ট যাচাই করো; একক টুলের ব্যর্থতা অ্যাপকে মারবে না।"
                e.tag.contains("START", true) -> hints += "START: permission/ViewModel/gate ধাপ আলাদা করে দেখো।"
                e.tag.contains("COMPOSE", true) -> hints += "COMPOSE: UI state null/absent হলে fallback দেখাও।"
            }
        }
        if (hints.isEmpty()) appendLine("কোনো পুনরাবৃত্ত সমস্যা নেই।")
        else hints.forEach { appendLine("• $it") }
    }

    /** রিপোর্টটা ডিভাইসে লেখে — ব্যবহারকারীর অনুমতি ছাড়া বাইরে যায় না। */
    @Synchronized
    fun flush(context: Context) {
        val text = report()
        runCatching {
            File(context.filesDir, "zara_diagnostics.txt").writeText(text)
        }
        if (Build.VERSION.SDK_INT >= 29) {
            runCatching {
                val resolver = context.contentResolver
                val projection = arrayOf(MediaStore.MediaColumns._ID)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
                val cursor = resolver.query(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    projection, selection, arrayOf(FILE_NAME), null
                )
                val existing = cursor?.use { c ->
                    if (c.moveToFirst())
                        c.getLong(c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                    else null
                }
                val uri = existing?.let {
                    ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, it)
                } ?: runCatching {
                    resolver.insert(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, FILE_NAME)
                            put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        }
                    )
                }.getOrNull()
                uri?.let { u -> resolver.openOutputStream(u, "wt")?.use { it.write(text.toByteArray()) } }
            }
        } else {
            runCatching {
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                dir.mkdirs()
                File(dir, FILE_NAME).writeText(text)
            }
        }
    }

    /** সব uncaught exception এখানে ধরা পড়ে — ক্র্যাশের আগে রিপোর্ট ফ্লাশ হয়। */
    fun install(context: Context) {
        appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            log("FATAL", "thread=${thread.name}", error)
            flush(context.applicationContext)
            previous?.uncaughtException(thread, error) ?: Runtime.getRuntime().exit(1)
        }
    }
}
