package com.zaraai.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
            if (missing.isNotEmpty()) requestPerms.launch(missing.toTypedArray())

            val vm = ViewModelProvider(this)[ZaraViewModel::class.java]
            zaraViewModel = vm
            vm.attachSecureGate { approved ->
                SecureGate.requireUnlock(this, approved) { vm.denyConfirmation() }
            }

            val startRoute = when (intent.getStringExtra("open_route")) {
                "assistant" -> ZaRaRoute.ASSISTANT
                else -> ZaRaRoute.HOME
            }
            setContent {
                MaterialTheme {
                    ZaRaApp(
                        vm = vm,
                        activity = this,
                        onRequestScreen = { screenLauncher.launch(vm.screenConsentIntent()) },
                        startRoute = startRoute
                    )
                }
            }
        } catch (t: Throwable) {
            Log.e("ZaRaStart", "startup failed", t)
            Toast.makeText(this, "ZaRa চালু হতে পারেনি — logcat দেখো (ZaRaStart)", Toast.LENGTH_LONG).show()
            setContent {
                MaterialTheme {
                    Text("ZaRa চালু হতে পারেনি।logcat-এ ZaRaStart / ZaRaCrash দেখো।")
                }
            }
        }
    }
}
