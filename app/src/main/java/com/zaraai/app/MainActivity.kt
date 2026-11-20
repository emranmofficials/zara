package com.zaraai.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
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
    private lateinit var screenLauncher: ActivityResultLauncher<android.content.Intent>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val needed = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.CAMERA,
            Manifest.permission.SEND_SMS,
            Manifest.permission.CALL_PHONE,
            Manifest.permission.READ_CONTACTS,
            Manifest.permission.WRITE_CONTACTS
        )
        if (Build.VERSION.SDK_INT >= 33) needed.add(Manifest.permission.POST_NOTIFICATIONS)
        if (needed.any {
                ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
            }) requestPerms.launch(needed.toTypedArray())

        val vm = ViewModelProvider(this)[ZaraViewModel::class.java]
        vm.attachSecureGate { approved ->
            SecureGate.requireUnlock(this, approved) { vm.denyConfirmation() }
        }
        screenLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result -> vm.grantScreen(result.resultCode, result.data ?: android.content.Intent()) }

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
    }
}
