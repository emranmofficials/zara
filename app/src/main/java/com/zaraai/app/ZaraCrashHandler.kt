package com.zaraai.app

import android.app.Application
import android.util.Log
import java.io.File

/**
 * ক্র্যাশ হলে পূর্ণ stack trace logcat-এ (ট্যাগ ZaRaCrash) এবং ডিভাইসে ফাইলে লেখে।
 * কোনো তথ্য বাইরে পাঠায় না — শুধু ব্যবহারকারীর নিজস্ব ডিভাইসে থাকে।
 */
class ZaraCrashHandler(private val app: Application) : Thread.UncaughtExceptionHandler {
    private val previous = Thread.getDefaultUncaughtExceptionHandler()

    override fun uncaughtException(thread: Thread, error: Throwable) {
        val report = buildString {
            append("ZaRa crash — ").append(System.currentTimeMillis()).append('\n')
            append("thread: ").append(thread.name).append('\n')
            append(Log.getStackTraceString(error))
        }
        runCatching { Log.e(TAG, report) }
        runCatching {
            File(app.filesDir, "zara_crash.txt").writeText(report.take(20_000))
        }
        previous?.uncaughtException(thread, error) ?: Runtime.getRuntime().exit(1)
    }

    companion object {
        private const val TAG = "ZaRaCrash"

        fun install(app: Application) {
            Thread.setDefaultUncaughtExceptionHandler(ZaraCrashHandler(app))
        }
    }
}
