package com.zaraai.app.agent

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.core.content.FileProvider
import org.json.JSONObject
import java.io.File

/**
 * ক্যামেরা টুল — Android-র নিজস্ব camera intent; ছবি শুধু ডিভাইসেই থাকে,
 * কোথাও আপলোড হয় না। Touch Guard-এর মতো গোপন ছবি এখানে নেই।
 */
fun buildCameraTools(context: Context, consent: ConsentManager, guardian: VoiceGuardian): List<Tool> {
    fun gate(name: String): JSONObject? = when {
        !guardian.allows(name) -> JSONObject().put("error", "এই রোলে $name চালানো যাবে না।")
        !consent.consume(name) -> JSONObject().put("error", "$name-এর অনুমতি নেই।")
        else -> null
    }
    return listOf(
        Tool("take_photo", "ক্যামেরা খুলে ছবি তোলে (শুধু ডিভাইসে)", true) { a ->
            gate("take_photo")?.let { return@Tool it }
            val file = File(context.cacheDir, "zara_photo_${System.currentTimeMillis()}.jpg")
            val uri: Uri = runCatching {
                FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            }.getOrElse { return@Tool JSONObject().put("error", "ফাইল সংরক্ষণের অনুমতি নেই।") }
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, uri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                if (a.optBoolean("selfie", false))
                    putExtra("android.intent.extras.CAMERA_FACING", 1)
            }
            runCatching {
                context.startActivity(intent)
                JSONObject().put("ok", true).put("path", file.absolutePath)
            }.getOrElse { JSONObject().put("error", "ক্যামেরা খোলা গেলো না: ${it.message}") }
        }
    )
}
