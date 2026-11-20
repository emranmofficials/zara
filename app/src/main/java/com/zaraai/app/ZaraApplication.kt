package com.zaraai.app

import android.app.Application

class ZaraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ZaraCrashHandler.install(this)
    }
}
