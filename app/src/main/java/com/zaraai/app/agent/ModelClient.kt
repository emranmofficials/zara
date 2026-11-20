package com.zaraai.app.agent

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/** Calls a user-configured OpenAI-compatible chat endpoint with the user's OWN key. */
class ModelClient(private val baseUrl: String, private val apiKey: String, private val model: String) {
    private val client = OkHttpClient()

    suspend fun chat(messages: JSONArray): String {
        val body = JSONObject()
            .put("model", model)
            .put("messages", messages)
            .toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/chat/completions")
            .header("Authorization", "Bearer $apiKey")
            .post(body).build()
        return client.newCall(request).execute().use { r ->
            if (!r.isSuccessful) throw IllegalStateException("LLM HTTP ${r.code}")
            JSONObject(r.body!!.string())
                .getJSONArray("choices").getJSONObject(0)
                .getJSONObject("message").optString("content", "")
        }
    }
}
