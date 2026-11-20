package com.zaraai.app.ui

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Maya-র MayaAssistActivity-র নিজস্ব সমতুল্য — ACTION_ASSIST দিয়ে ZaRa কথা বলে। */
class AssistantActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val i = Intent(this, MainActivity::class.java).apply {
            putExtra("open_route", "assistant")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(i)
        finish()
    }
}
