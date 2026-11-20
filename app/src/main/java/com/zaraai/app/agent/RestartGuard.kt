package com.zaraai.app.agent

import android.content.Context
import java.io.File

/** Restart-storm guard — বারবার crash/restart হলে কিছুক্ষণের জন্য নীরব থাকে। */
class RestartGuard(context: Context) {
    private val file = File(context.filesDir, "zara_starts.txt")

    fun allow(): Boolean {
        val now = System.currentTimeMillis()
        val times = read().filter { now - it < 60_000L }.toMutableList()
        val allowed = times.size < 5
        times.add(now)
        file.writeText(times.joinToString(","))
        return allowed
    }

    private fun read(): List<Long> = runCatching {
        if (!file.exists()) emptyList()
        else file.readText().split(",").mapNotNull { it.trim().toLongOrNull() }
    }.getOrDefault(emptyList())
}
