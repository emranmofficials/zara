package com.zaraai.app.agent

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/** Maya-র NoticeWorker-এর নিজস্ব সমতুল্য — শুধু স্থানীয়, কোনো notice সার্ভার নেই। */
class NoticeWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val text = inputData.getString("text") ?: "ZaRa আপডেট"
        ReminderReceiver.show(applicationContext, text.take(120))
        return Result.success()
    }
}
