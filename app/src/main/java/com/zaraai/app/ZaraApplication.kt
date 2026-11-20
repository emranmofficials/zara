package com.zaraai.app

import android.app.Application
import com.zaraai.app.diag.ZaraDiagnostics

class ZaraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ZaraDiagnostics.install(this)
        ZaraDiagnostics.mark("APP onCreate")
        ZaraDiagnostics.flush(this)
    }
}
