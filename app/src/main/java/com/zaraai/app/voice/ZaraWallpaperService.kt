package com.zaraai.app.voice

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import kotlin.math.sin

/** Maya-র 3D wallpaper-এর বদলে নিজস্ব, হালকা canvas wallpaper — কোনো Maya অ্যাসেট নয়। */
class ZaraWallpaperService : WallpaperService() {
    override fun onCreateEngine(): Engine = ZaraEngine()

    private inner class ZaraEngine : Engine() {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
        private var t = 0f

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            Thread {
                while (isVisible) {
                    val c = holder.lockCanvas() ?: break
                    draw(c)
                    holder.unlockCanvasAndPost(c)
                    t += 0.03f
                    try { Thread.sleep(40) } catch (e: InterruptedException) { break }
                }
            }.start()
        }

        private fun draw(c: Canvas) {
            c.drawColor(Color.rgb(12, 18, 30))
            val w = c.width; val h = c.height
            for (i in 0..6) {
                val r = (i + 1) * (minOf(w, h) / 14f) + sin(t + i) * 12f
                paint.color = Color.argb(90, 60 + i * 18, 180 - i * 12, 220 - i * 8)
                paint.strokeWidth = 2f
                c.drawCircle(w / 2f, h / 2f, r, paint)
            }
        }
    }
}
