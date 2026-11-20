package com.zaraai.app.data

/**
 * ZaRa-র কথা বলার মোড — তুমি নিজে বেছে নাও কেমন স্বরে কথা বলবে।
 * কোনো Maya স্ক্রিপ্ট নয়; শুধু স্বর/গতির নিয়ামক + নিজস্ব লেখা নির্দেশ।
 */
enum class SpeechMode(
    val label: String,
    val rate: Float,
    val pitch: Float,
    val cue: String
) {
    PUNCHY(
        "চটপট", 1.05f, 1.0f,
        "ছোট ছোট বাক্য। ফল আগে, বাখ্যা পরে। একটু কড়া-মজার, আত্মবিশ্বাসী।"
    ),
    CALM(
        "শান্ত", 0.95f, 0.98f,
        "ধীর, গাম্ভীর্যপূর্ণ। এক লাইনে এক কথা। তর্ক নয়, স্পষ্টতা।"
    ),
    STRICT(
        "কড়া", 1.0f, 0.95f,
        "সংক্ষিপ্ত ও নির্ণায়ক। অপ্রয়োজনীয় কথা নয়। সিদ্ধান্ত দাও, প্রশ্ন নয়।"
    ),
    WITTY(
        "মজার", 1.08f, 1.05f,
        "চটপট ব্যঙ্গ-মজার, কিন্তু অশ্লীল বা অহংকারী নয়। কাজের কথা আগে, মজা পাশে।"
    );

    companion object {
        fun from(name: String?): SpeechMode =
            values().firstOrNull { it.name == name } ?: PUNCHY
    }
}
