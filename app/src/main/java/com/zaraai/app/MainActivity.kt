package com.zaraai.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModelProvider
import com.zaraai.app.ui.SecureGate
import com.zaraai.app.ui.ZaRaApp
import com.zaraai.app.ui.ZaRaRoute
import com.zaraai.app.ui.ZaraViewModel

class MainActivity : FragmentActivity() {
    private val requestPerms = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()) { }
    private val screenLauncher: ActivityResultLauncher<android.content.Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            runCatching { zaraViewModel?.grantScreen(result.resultCode, result.data ?: android.content.Intent()) }
        }
    private var zaraViewModel: ZaraViewModel? = null
    private var permissionRequested = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        var failure: String? = null
        var vm: ZaraViewModel? = null
        var startRoute = ZaRaRoute.HOME

        // ধাপ ১ — অনুমতি (আসল চালুর আগে, আলাদা guarding)
        try {
            val needed = mutableListOf(
                Manifest.permission.RECORD_AUDIO,
                Manifest.permission.CAMERA,
                Manifest.permission.SEND_SMS,
                Manifest.permission.CALL_PHONE,
                Manifest.permission.READ_CONTACTS,
                Manifest.permission.WRITE_CONTACTS
            )
            if (Build.VERSION.SDK_INT >= 33) needed.add(Manifest.permission.POST_NOTIFICATIONS)
            val missing = needed.filter {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }
            if (missing.isNotEmpty() && !permissionRequested) {
                permissionRequested = true
                requestPerms.launch(missing.toTypedArray())
            }
        } catch (t: Throwable) {
            Log.e("ZaRaStart", "permission stage failed", t)
            failure = "অনুমতি ধাপ: ${t.stackTraceToString().take(1600)}"
        }

        // ধাপ ২ — ViewModel
        if (failure == null) {
            try {
                vm = ViewModelProvider(this)[ZaraViewModel::class.java]
                zaraViewModel = vm
            } catch (t: Throwable) {
                Log.e("ZaRaStart", "viewmodel stage failed", t)
                failure = "ViewModel ধাপ: ${t.stackTraceToString().take(1600)}"
            }
        }

        // ধাপ ৩ — gate + route
        if (failure == null && vm != null) {
            try {
                val model = vm!!
                model.attachSecureGate { approved ->
                    SecureGate.requireUnlock(this, approved) { model.denyConfirmation() }
                }
                startRoute = when (intent.getStringExtra("open_route")) {
                    "assistant" -> ZaRaRoute.ASSISTANT
                    else -> ZaRaRoute.HOME
                }
            } catch (t: Throwable) {
                Log.e("ZaRaStart", "gate stage failed", t)
                failure = "Gate ধাপ: ${t.stackTraceToString().take(1600)}"
            }
        }

        // ধাপ ৪ — UI
        setContent {
            MaterialTheme {
                if (failure == null && vm != null) {
                    ZaRaApp(
                        vm = vm!!,
                        activity = this,
                        onRequestScreen = { screenLauncher.launch(vm!!.screenConsentIntent()) },
                        startRoute = startRoute
                    )
                } else {
                    Column(Modifier.verticalScroll(rememberScrollState())) {
                        Text("ZaRa চালু হতে পারেনি। নিচের লাইনটা আমাকে পাঠাও — ঠিক করে দেব।")
                        Text("ZaRaStart · ${failure ?: "unknown"}")
                    }
                }
            }
        }
    }
}
