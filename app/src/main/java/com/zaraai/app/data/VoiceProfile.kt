package com.zaraai.app.data

/**
 * ZaRa-র নিজস্ব কন্ঠ-প্রোফাইল — সিস্টেমের বাংলা voice + আত্মবিশ্বাসী ডেলিভারি।
 * এটা ZaRa-র নিজস্ব কনফিগারেশন; কোনো Maya voice pack/মডেল এখানে নেই।
 */
data class VoiceProfile(
    val voiceName: String = "",     // খালি = প্রথম উপলব্ধ bn voice
    val speed: Float = 1.05f,       // একটু চটপট
    val pitch: Float = 1.0f
)
