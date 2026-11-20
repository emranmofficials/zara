package com.zaraai.app.agent

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/** কনট্যাক্ট টুল — runtime permission + biometric + consent ছাড়া কিছুই পড়া/লেখা হয় না। */
fun buildContactTools(context: Context, consent: ConsentManager, guardian: VoiceGuardian): List<Tool> {
    fun gate(name: String, permission: String): JSONObject? = when {
        !guardian.allows(name) -> JSONObject().put("error", "এই রোলে $name চালানো যাবে না।")
        !consent.consume(name) -> JSONObject().put("error", "$name-এর অনুমতি নেই।")
        ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED ->
            JSONObject().put("error", "$permission অনুমতি দাও।")
        else -> null
    }

    return listOf(
        Tool("find_contact", "নাম দিয়ে কনট্যাক্ট খোঁজে", true) { a ->
            gate("find_contact", Manifest.permission.READ_CONTACTS)?.let { return@Tool it }
            val q = a.optString("name", "")
            if (q.isBlank()) return@Tool JSONObject().put("error", "নাম বলো।")
            val out = JSONArray()
            runCatching {
                context.contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI, null,
                    "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                    arrayOf("%$q%"), null
                )?.use { c ->
                    val ni = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val pi = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    while (c.moveToNext() && out.length() < 10) {
                        out.put(JSONObject()
                            .put("name", if (ni >= 0) c.getString(ni) else "")
                            .put("number", if (pi >= 0) c.getString(pi) else ""))
                    }
                }
            }
            JSONObject().put("ok", true).put("results", out)
        },
        Tool("save_contact", "নতুন কনট্যাক্ট যোগ করে", true) { a ->
            gate("save_contact", Manifest.permission.WRITE_CONTACTS)?.let { return@Tool it }
            val name = a.optString("name")
            val number = a.optString("number")
            if (name.isBlank() || number.isBlank())
                return@Tool JSONObject().put("error", "নাম আর নম্বর দাও।")
            try {
                val values = ContentValues().apply {
                    put(ContactsContract.RawContacts.ACCOUNT_TYPE, "")
                    put(ContactsContract.RawContacts.ACCOUNT_NAME, "")
                }
                val raw = context.contentResolver.insert(
                    ContactsContract.RawContacts.CONTENT_URI, values
                ) ?: return@Tool JSONObject().put("error", "যোগ করা গেলো না।")
                val id = raw.lastPathSegment
                context.contentResolver.insert(
                    ContactsContract.Data.CONTENT_URI,
                    ContentValues().apply {
                        put(ContactsContract.Data.RAW_CONTACT_ID, id)
                        put(ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                        put(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                    }
                )
                context.contentResolver.insert(
                    ContactsContract.Data.CONTENT_URI,
                    ContentValues().apply {
                        put(ContactsContract.Data.RAW_CONTACT_ID, id)
                        put(ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                        put(ContactsContract.CommonDataKinds.Phone.NUMBER, number)
                        put(ContactsContract.CommonDataKinds.Phone.TYPE,
                            ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                    }
                )
                JSONObject().put("ok", true).put("name", name)
            } catch (e: Exception) {
                JSONObject().put("error", "কনট্যাক্ট যোগ করা গেলো না: ${e.message}")
            }
        }
    )
}
