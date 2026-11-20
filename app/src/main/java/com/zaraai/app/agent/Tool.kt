package com.zaraai.app.agent

/** A tool the agent may call. Destructive/privileged tools require explicit confirmation. */
data class Tool(
    val name: String,
    val description: String,
    val requiresConfirmation: Boolean = true,
    val run: suspend (args: org.json.JSONObject) -> org.json.JSONObject
)
