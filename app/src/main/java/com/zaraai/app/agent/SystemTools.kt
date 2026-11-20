package com.zaraai.app.agent

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ClipboardManager
import android.content.ClipData
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * ডিভাইস কন্ট্রোল টুল — Maya-র সিস্টেম-সেটিংস ক্যাটাগরির নিজস্ব, সীমিত বাস্তবায়ন।
 * কোনো shell, কোনো server-pushed bundle, কোনো covert অ্যাকশন নেই।
 * প্রতিটি সংবেদনশীল টুলের আগে biometric + consent + রোল-গেট।
 */
fun buildSystemTools(
    context: Context,
    consent: ConsentManager,
    guardian: VoiceGuardian
): List<Tool> {
    fun gate(name: String): JSONObject? = when {
        !guardian.allows(name) -> JSONObject().put("error", "এই রোলে $name চালানো যাবে না।")
        !consent.consume(name) -> JSONObject().put("error", "অনুমতি নেই বা মেয়াদোত্তীর্ণ — $name চালাইনি।")
        else -> null
    }

    return listOf(
        Tool("set_volume", "ভলিউম বাড়া/কমা/নির্দিষ্ট লেভেল", true) { a ->
            gate("set_volume")?.let { return@Tool it }
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val level = if (a.has("level")) a.optInt("level").coerceIn(0, max)
                        else (cur + a.optInt("delta")).coerceIn(0, max)
            am.setStreamVolume(AudioManager.STREAM_MUSIC, level, AudioManager.FLAG_SHOW_UI)
            JSONObject().put("ok", true).put("level", level)
        },
        Tool("set_ringer", "রিংগার silent/vibrate/normal", true) { a ->
            gate("set_ringer")?.let { return@Tool it }
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val mode = when (a.optString("mode").lowercase()) {
                "silent" -> AudioManager.RINGER_MODE_SILENT
                "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                else -> AudioManager.RINGER_MODE_NORMAL
            }
            am.ringerMode = mode
            JSONObject().put("ok", true).put("mode", a.optString("mode"))
        },
        Tool("set_brightness", "স্ক্রিন উজ্জ্বলতা বদলায় (সিস্টেম অনুমতি সাপেক্ষে)", true) { a ->
            gate("set_brightness")?.let { return@Tool it }
            val value = a.optInt("level", -1)
            val result = runCatching {
                if (Settings.System.canWrite(context) && value in 0..255) {
                    Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, value)
                    JSONObject().put("ok", true).put("level", value)
                } else {
                    JSONObject().put("error", "ব্রাইটনেস বদলাতে সিস্টেম অনুমতি দাও (Settings → Modify system settings)।")
                }
            }.getOrElse { JSONObject().put("error", "ব্রাইটনেস বদলানো গেলো না: ${it.message}") }
            result
        },
        Tool("set_torch", "ক্যামেরা ফ্ল্যাশলাইট অন/অফ", true) { a ->
            gate("set_torch")?.let { return@Tool it }
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED
            ) return@Tool JSONObject().put("error", "টর্চের জন্য ক্যামেরা অনুমতি দাও।")
            val cam = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cam.cameraIdList.firstOrNull()
                ?: return@Tool JSONObject().put("error", "ক্যামেরা পাওয়া গেলো না।")
            runCatching {
                cam.setTorchMode(id, a.optBoolean("on", true))
                JSONObject().put("ok", true)
            }.getOrElse { JSONObject().put("error", "টর্চ চালানো গেলো না: ${it.message}") }
        },
        Tool("lock_device", "ডিভাইস লক (ডিভাইস অ্যাডমিন অন থাকলে)", true) { _ ->
            gate("lock_device")?.let { return@Tool it }
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val admin = ComponentName("com.zaraai.app", "com.zaraai.app.ZaraDeviceAdmin")
            if (dpm.isAdminActive(admin)) {
                dpm.lockNow()
                JSONObject().put("ok", true)
            } else {
                JSONObject().put("error", "লক করতে ডিভাইস অ্যাডমিন অনুমতি দাও। আমি নিজে PIN চাইব না।")
            }
        },
        Tool("open_app", "নাম বা প্যাকেজ দিয়ে অ্যাপ খোলে", true) { a ->
            gate("open_app")?.let { return@Tool it }
            val q = a.optString("name").trim().lowercase()
            if (q.isBlank()) return@Tool JSONObject().put("error", "অ্যাপের নাম বলো।")
            val pm = context.packageManager
            val app = pm.getInstalledApplications(0).firstOrNull {
                it.packageName.contains(q) || runCatching {
                    it.loadLabel(pm).toString().lowercase().contains(q)
                }.getOrDefault(false)
            }
            if (app == null) return@Tool JSONObject().put("error", "'$q' অ্যাপ পাওয়া গেলো না।")
            val intent = pm.getLaunchIntentForPackage(app.packageName)
                ?: return@Tool JSONObject().put("error", "এই অ্যাপ খোলা যায় না।")
            runCatching {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                JSONObject().put("ok", true).put("package", app.packageName)
            }.getOrElse { JSONObject().put("error", "খোলা গেলো না: ${it.message}") }
        },
        Tool("open_settings", "Android সেটিংস খোলে", false) { _ ->
            runCatching {
                context.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                JSONObject().put("ok", true)
            }.getOrElse { JSONObject().put("error", "সেটিংস খোলা গেলো না") }
        },
        Tool("search_web", "ডিফল্ট ব্রাউজারে ওয়েব সার্চ", false) { a ->
            val q = a.optString("query", a.optString("text"))
            if (q.isBlank()) return@Tool JSONObject().put("error", "কী খুঁজবো?")
            runCatching {
                val i = Intent(Intent.ACTION_WEB_SEARCH).apply {
                    putExtra(android.provider.SearchManager.QUERY, q)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(i)
                JSONObject().put("ok", true).put("query", q)
            }.getOrElse { JSONObject().put("error", "সার্চ চালানো গেলো না") }
        },
        Tool("media_control", "গান play/pause/next/prev", false) { a ->
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val code = when (a.optString("action")) {
                "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            }
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
            JSONObject().put("ok", true)
        },
        Tool("write_clipboard", "ক্লিপবোর্ডে লেখা কপি করে", true) { a ->
            gate("write_clipboard")?.let { return@Tool it }
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("zara", a.optString("text")))
            JSONObject().put("ok", true)
        },
        Tool("read_clipboard", "ক্লিপবোর্ড পড়ে", true) { _ ->
            gate("read_clipboard")?.let { return@Tool it }
            val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val text = runCatching {
                cm.primaryClip?.getItemAt(0)?.text?.toString().orEmpty()
            }.getOrDefault("")
            JSONObject().put("ok", true).put("text", text)
        },
        Tool("get_notifications", "সাম্প্রতিক নোটিফিকেশন পড়ে (ব্যবহারকারী অনুমতি দিলে)", true) { _ ->
            gate("get_notifications")?.let { return@Tool it }
            val items = ZaraNotificationListener.latest()
            JSONObject().put("ok", true)
                .put("results", JSONArray(items))
                .put("note", "নোটিফিকেশন অ্যাক্সেস চালু না থাকলে খালি দেখাবে।")
        },
        Tool("go_to_sleep", "ঘুমের মোড — শুধু জরুরি কথা বলে", false) { _ ->
            ModeManager.set(ModeManager.Mode.SLEEP)
            JSONObject().put("ok", true)
        },
        Tool("set_driving_mode", "ড্রাইভিং মোড — ছোট উত্তর", false) { _ ->
            ModeManager.set(ModeManager.Mode.DRIVING)
            JSONObject().put("ok", true)
        },
        Tool("set_normal_mode", "স্বাভাবিক মোডে ফেরত", false) { _ ->
            ModeManager.set(ModeManager.Mode.NORMAL)
            JSONObject().put("ok", true)
        },
        Tool("set_quiet_mode", "নীরব মোড — কন্ঠ বন্ধ", false) { _ ->
            ModeManager.set(ModeManager.Mode.QUIET)
            JSONObject().put("ok", true)
        },
        Tool("send_sms", "SMS পাঠায় (অনুমতি + কনফার্মেশন সহ)", true) { a ->
            gate("send_sms")?.let { return@Tool it }
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED
            ) return@Tool JSONObject().put("error", "SMS অনুমতি দাও।")
            val number = a.optString("number")
            val text = a.optString("text")
            runCatching {
                android.telephony.SmsManager.getDefault().sendTextMessage(number, null, text, null, null)
                JSONObject().put("ok", true)
            }.getOrElse { JSONObject().put("error", "SMS যায়নি: ${it.message}") }
        },
        Tool("make_call", "কল করে (অনুমতি + কনফার্মেশন সহ)", true) { a ->
            gate("make_call")?.let { return@Tool it }
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE)
                != PackageManager.PERMISSION_GRANTED
            ) return@Tool JSONObject().put("error", "কল করার অনুমতি দাও।")
            val number = a.optString("number")
            runCatching {
                context.startActivity(
                    Intent(Intent.ACTION_CALL, Uri.parse("tel:${Uri.encode(number)}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                JSONObject().put("ok", true)
            }.getOrElse { JSONObject().put("error", "কল শুরু হয়নি: ${it.message}") }
        }
    )
}
