package com.zaraai.app.agent

/**
 * এক-বারের, সময়সীমাবদ্ধ অনুমতি। প্রতিটি সংবেদনশীল কাজের আগে grant নিতে হয়,
 * ব্যবহারের পর immediately consume হয় — কোনো স্থায়ী/স্পুফযোগ্য অনুমতি নেই।
 */
class ConsentManager {
    data class Grant(val action: String, val expiresAt: Long)

    private val grants = mutableMapOf<String, Grant>()

    fun grant(action: String, ttlMs: Long = 60_000L) {
        grants[action] = Grant(action, System.currentTimeMillis() + ttlMs)
    }

    fun consume(action: String): Boolean = synchronized(this) {
        val g = grants.remove(action) ?: return false
        if (System.currentTimeMillis() > g.expiresAt) false else true
    }

    fun pending(action: String): Boolean = grants.containsKey(action)

    fun revokeAll() = grants.clear()
}
