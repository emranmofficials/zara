package com.zaraai.app.voice

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager

/**
 * স্ক্রিন ক্যাপচারের একমাত্র পথ — Android-র নিজস্ব consent dialog +
 * সবসময় দৃশ্যমান foreground notification। ফ্রেম শুধু on-device sink-এ যায়;
 * কোনো আপলোড/ক্লাউড/গোপন ক্যাপচার নেই।
 */
class MediaProjectionGate(private val context: Context) {
    companion object {
        const val REQUEST_CODE = 9001
    }

    private var projection: MediaProjection? = null

    /** on-device ফ্রেম প্রক্রিয়াকরণের hook — null হলে কিছুই পড়া হয় না। */
    var frameSink: ((Any) -> Unit)? = null

    fun consentIntent(): Intent {
        val mgr = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        return mgr.createScreenCaptureIntent()
    }

    fun grant(resultCode: Int, data: Intent) {
        if (resultCode != android.app.Activity.RESULT_OK) return
        val mgr = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        projection = mgr.getMediaProjection(resultCode, data)
        val i = Intent(context, ScreenCaptureService::class.java).setAction(ScreenCaptureService.ACTION_START)
        context.startForegroundService(i)
    }

    fun stop() {
        frameSink = null
        projection?.stop()
        projection = null
        context.stopService(Intent(context, ScreenCaptureService::class.java))
    }

    val active: Boolean get() = projection != null
}
