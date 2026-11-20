package com.zaraai.app.voice

import android.service.voice.VoiceInteractionService

/**
 * Maya-র MayaVoiceInteractionService-র নিজস্ব সমতুল্য — Android Assistant হিসেবে
 * ZaRa-কে বেছে নেওয়ার entry point। কোনো Maya ভয়েস-ইন্টারঅ্যাকশন মডেল নেই।
 */
class ZaraVoiceInteractionService : VoiceInteractionService()
