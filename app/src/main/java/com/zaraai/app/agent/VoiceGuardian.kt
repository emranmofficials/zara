package com.zaraai.app.agent

/**
 * ভয়েস-রোল গেট — Maya-র ভয়েস-মডেল/ম্যানিফেস্ট নয়; Platform biometric + ব্যবহারকারীর
 * নিজস্ব speaker-verifier hook। কে কথা বলছে তা শুধু এই ডিভাইসে নির্ধারণ হয়।
 */
class VoiceGuardian {
    enum class Role(val label: String) {
        OWNER("মালিক"), FRIEND("বন্ধু"), GUEST("অতিথি"), BLOCKED("ব্লক")
    }

    var current: Role = Role.OWNER
        private set

    /** ব্যবহারকারীর বৈধ মডেল বসালে কাজ করে; null হলে OWNER ধরে নেওয়া হয়। */
    var verifier: ((ShortArray) -> String)? = null

    fun identify(pcm: ShortArray): Role {
        val v = verifier ?: return Role.OWNER
        current = runCatching { v(pcm) }.getOrNull()?.let { label ->
            Role.values().firstOrNull {
                it.name.equals(label, ignoreCase = true) || it.label == label
            }
        } ?: Role.GUEST
        return current
    }

    fun setRole(role: Role) { current = role }

    /** রোল অনুযায়ী টুলের উপর সীমা — guest/blocked কখনো যোগাযোগ টুল পায় না। */
    fun allows(tool: String): Boolean = when (current) {
        Role.OWNER -> true
        Role.FRIEND -> tool !in PRIVILEGED
        Role.GUEST -> tool in SAFE
        Role.BLOCKED -> false
    }

    companion object {
        private val PRIVILEGED = setOf(
            "send_sms", "make_call", "lock_device", "set_torch", "set_reminder", "add_note",
            "set_volume", "set_brightness", "set_ringer", "open_app", "write_clipboard",
            "read_clipboard", "get_notifications"
        )
        private val SAFE = setOf("get_time", "get_battery", "recall_notes", "search_web")
    }
}
