package com.zaraai.app.agent

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.zaraai.app.data.MemoryStore

/** Maya-র AssistantNudgeReceiver-এর নিজস্ব সমতুল্য — স্থানীয় মেমরি থেকে ছোট্ট নudge। */
class ProactiveWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val notes = MemoryStore(applicationContext).recall("মনে", 1)
        if (notes.isEmpty()) return Result.success()
        // কোনো ক্লাউড পুশ নেই; স্থানীয় নোটিফিকেশনই যথেষ্ট
        ReminderReceiver.show(applicationContext, "মনে আছে? ${notes.first().take(80)}")
        return Result.success()
    }
}
