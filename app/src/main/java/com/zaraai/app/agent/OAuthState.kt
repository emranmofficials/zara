package com.zaraai.app.agent

import android.util.Base64
import java.security.SecureRandom

/**
 * নিজস্ব connector-এর জন্য OAuth 2.0 PKCE — state + S256 challenge + expiry।
 * কোনো Maya client ID / secret এখানে নেই; সব কনফিগারেশন ব্যবহারকারীর নিজস্ব।
 */
object OAuthState {
    data class Pending(val state: String, val verifier: String, val expiresAt: Long)

    private const val TTL_MS = 10 * 60 * 1000L
    private val pending = mutableMapOf<String, Pending>()
    private val random = SecureRandom()

    fun begin(): Pending {
        val verifier = randomToken(32)
        val state = randomToken(16)
        val challenge = Base64.encodeToString(
            sha256(verifier.toByteArray()), Base64.URL_SAFE or Base64.NO_WRAP
        )
        val p = Pending(state, verifier, System.currentTimeMillis() + TTL_MS)
        pending[state] = p
        return p.copy(verifier = "$verifier|S256:$challenge")
    }

    fun validate(state: String): Boolean = synchronized(this) {
        val p = pending.remove(state) ?: return false
        System.currentTimeMillis() <= p.expiresAt
    }

    private fun randomToken(bytes: Int): String {
        val b = ByteArray(bytes); random.nextBytes(b)
        return Base64.encodeToString(b, Base64.URL_SAFE or Base64.NO_WRAP)
    }

    private fun sha256(data: ByteArray): ByteArray =
        java.security.MessageDigest.getInstance("SHA-256").digest(data)
}
