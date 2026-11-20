package com.zaraai.app.ui

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * সংবেদনশীল কাজের আগে Android-র নিজস unlock যাচাই।
 * ZaRa কোনো PIN/pattern সংরক্ষণ বা replay করে না — সিস্টেমই যাচাই করে।
 * PIN-replay / spoofable receiver এখানে নেই।
 */
object SecureGate {
    fun requireUnlock(
        activity: FragmentActivity,
        onApproved: () -> Unit,
        onDenied: () -> Unit = {}
    ) {
        val executor = ContextCompat.getMainExecutor(activity)
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                onApproved()
            }
            override fun onAuthenticationFailed() { /* retry allowed */ }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                onDenied()
            }
        }
        val prompt = BiometricPrompt(activity, executor, callback)
        val base = BiometricPrompt.PromptInfo.Builder()
            .setTitle("ZaRa — নিরাপত্তা যাচাই")
            .setSubtitle("সংবেদনশীল কাজের আগে নিজের unlock দিয়ে নিশ্চিত হও")
            .setDescription("ZaRa কোনো PIN বা প্যাটার্ন সংরক্ষণ বা replay করে না।")

        // DEVICE_CREDENTIAL-এ negative button দেওয়া যায় না — তাই fallback
        val info = try {
            base.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
            ).build()
        } catch (e: Exception) {
            base.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("বাতিল")
                .build()
        }
        prompt.authenticate(info)
    }
}
