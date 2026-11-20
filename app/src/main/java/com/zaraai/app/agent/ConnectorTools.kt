package com.zaraai.app.agent

import com.zaraai.app.data.ZaraSettings
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Weather/news/search/market/email-এর জন্য সাধারণ HTTP connector — শুধু ব্যবহারকারীর
 * নিজস্ব দেওয়া URL/key থেকে। কোনো Maya host বা embedded credential নেই।
 * `connectorsJson` উদাহরণ:
 * {"weather":"https://.../{q}&key={key}","news":"https://...","search":"https://...","market":"https://..."}
 */
fun buildConnectorTools(settings: () -> ZaraSettings): List<Tool> {
    val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS).readTimeout(8, TimeUnit.SECONDS).build()

    fun call(kind: String, args: JSONObject): JSONObject {
        val cfg = runCatching { JSONObject(settings().connectorsJson) }.getOrDefault(JSONObject())
        val template = cfg.optString(kind, "")
        if (template.isBlank())
            return JSONObject().put("error", "$kind connector সেট করা নেই — সেটিংসে নিজস্ব URL দাও।")
        val q = args.optString("query", args.optString("q", args.optString("text", "")))
        val key = cfg.optString("key", "")
        val url = template.replace("{q}", java.net.URLEncoder.encode(q, "UTF-8"))
            .replace("{query}", java.net.URLEncoder.encode(q, "UTF-8"))
            .replace("{key}", key)
        if (!url.startsWith("https://", ignoreCase = true))
            return JSONObject().put("error", "শুধু https:// endpoint অনুমোদিত।")
        return runCatching {
            val req = Request.Builder().url(url)
                .header("User-Agent", "ZaRa/0.1")
                .also { if (key.isNotBlank()) it.header("Authorization", "Bearer $key") }
                .build()
            client.newCall(req).execute().use { r ->
                val body = r.body?.string().orEmpty().take(4000)
                if (!r.isSuccessful) JSONObject().put("error", "HTTP ${r.code}")
                else runCatching { JSONObject(body) }
                    .getOrDefault(JSONObject().put("result", body))
            }
        }.getOrElse { JSONObject().put("error", "connector ব্যর্থ: ${it.message}") }
    }

    return listOf(
        Tool("get_weather", "নিজস্ব weather endpoint থেকে আবহাওয়া", false) { call("weather", it) },
        Tool("get_news", "নিজস্ব news endpoint থেকে খবর", false) { call("news", it) },
        Tool("search_provider", "নিজস্ব search endpoint", false) { call("search", it) },
        Tool("get_market", "নিজস্ব market endpoint", false) { call("market", it) },
        Tool("send_email", "নিজস্ব email/webhook endpoint (consent সহ)", true) { call("email", it) },
        Tool("send_to_pc", "ব্যবহারকারীর নিজস্ব relay-এ পাঠায় (consent সহ)", true) { call("pc", it) }
    )
}
