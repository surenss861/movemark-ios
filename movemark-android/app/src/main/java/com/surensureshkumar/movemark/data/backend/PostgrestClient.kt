package com.surensureshkumar.movemark.data.backend

import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.serializer
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/** A Data API request the server refused. The message is for logs; screens map it to their own copy. */
class PostgrestException(val status: Int, val code: String?, val serverMessage: String?) :
    Exception("Data API request failed (HTTP $status, ${code ?: "no code"})")

/**
 * Filters, ordering and paging for one Data API request, in PostgREST's query-string syntax.
 * Every list read sets an explicit [order] (ending with `id` as tie-breaker) and a [limit].
 */
class PostgrestQuery internal constructor() {
    internal val params = mutableListOf<Pair<String, String>>()

    fun select(columns: String) = apply { params += "select" to columns }
    fun eq(column: String, value: String) = apply { params += column to "eq.$value" }
    fun gt(column: String, value: String) = apply { params += column to "gt.$value" }
    fun isIn(column: String, values: Collection<String>) =
        apply { params += column to "in.(${values.joinToString(",") { quote(it) }})" }
    fun isNull(column: String) = apply { params += column to "is.null" }
    fun notNull(column: String) = apply { params += column to "not.is.null" }

    /** Raw `or=(…)` expression; quote values with [quote]. */
    fun or(expression: String) = apply { params += "or" to "($expression)" }

    fun order(column: String, ascending: Boolean = true) = apply {
        val term = "$column.${if (ascending) "asc" else "desc"}"
        val existing = params.indexOfFirst { it.first == "order" }
        if (existing >= 0) params[existing] = "order" to "${params[existing].second},$term" else params += "order" to term
    }

    fun limit(count: Int) = apply { params += "limit" to count.toString() }

    companion object {
        /** A PostgREST list/`or` value in double quotes, so commas, dots and parentheses stay literal. */
        fun quote(value: String): String = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }
}

/**
 * First-party client for the Neon Data API (PostgREST): select, insert, upsert, update, delete and RPC
 * over [AuthenticatedTransport], with kotlinx.serialization row models. RLS decides which rows a request
 * can touch.
 */
class PostgrestClient(
    private val baseUrl: HttpUrl?,
    private val transport: AuthenticatedTransport,
) {
    val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        // Unset columns are left to their database defaults (created_at, ids generated server-side, …).
        explicitNulls = false
    }

    suspend fun <T> select(table: String, deserializer: KSerializer<T>, build: PostgrestQuery.() -> Unit): List<T> {
        val query = PostgrestQuery().apply(build)
        if (query.params.none { it.first == "select" }) query.select("*")
        val body = send(Request.Builder().url(url(table, query)).get())
        return json.decodeFromString(ListSerializer(deserializer), body)
    }

    suspend inline fun <reified T> select(table: String, noinline build: PostgrestQuery.() -> Unit): List<T> =
        select(table, serializer<T>(), build)

    /** Inserts [body] (an object or an array) and returns the inserted rows (`Prefer: return=representation`). */
    suspend fun <T> insertReturning(table: String, body: JsonElement, deserializer: KSerializer<T>): List<T> {
        val text = send(
            Request.Builder()
                .url(url(table, PostgrestQuery()))
                .header("Prefer", "return=representation")
                .post(body.toString().toRequestBody(JSON_MEDIA)),
        )
        return json.decodeFromString(ListSerializer(deserializer), text)
    }

    suspend inline fun <reified B, reified T> insertReturning(table: String, body: B): List<T> =
        insertReturning(table, json.encodeToJsonElement(serializer<B>(), body), serializer<T>())

    suspend fun insert(table: String, body: JsonElement) {
        send(
            Request.Builder()
                .url(url(table, PostgrestQuery()))
                .header("Prefer", "return=minimal")
                .post(body.toString().toRequestBody(JSON_MEDIA)),
        )
    }

    suspend inline fun <reified B> insert(table: String, body: B) =
        insert(table, json.encodeToJsonElement(serializer<B>(), body))

    /** Inserts unless a row with the same [onConflict] key exists; an existing row is left untouched. */
    suspend fun insertIgnoringDuplicates(table: String, body: JsonElement, onConflict: String) {
        send(
            Request.Builder()
                .url(url(table, PostgrestQuery().apply { params += "on_conflict" to onConflict }))
                .header("Prefer", "resolution=ignore-duplicates,return=minimal")
                .post(body.toString().toRequestBody(JSON_MEDIA)),
        )
    }

    suspend inline fun <reified B> insertIgnoringDuplicates(table: String, body: B, onConflict: String) =
        insertIgnoringDuplicates(table, json.encodeToJsonElement(serializer<B>(), body), onConflict)

    suspend fun update(table: String, patch: JsonElement, filter: PostgrestQuery.() -> Unit) {
        val query = PostgrestQuery().apply(filter)
        require(query.params.isNotEmpty()) { "Refusing an unfiltered update of $table" }
        send(
            Request.Builder()
                .url(url(table, query))
                .header("Prefer", "return=minimal")
                .patch(patch.toString().toRequestBody(JSON_MEDIA)),
        )
    }

    suspend inline fun <reified B> update(table: String, patch: B, noinline filter: PostgrestQuery.() -> Unit) =
        update(table, json.encodeToJsonElement(serializer<B>(), patch), filter)

    suspend fun delete(table: String, filter: PostgrestQuery.() -> Unit) {
        val query = PostgrestQuery().apply(filter)
        require(query.params.isNotEmpty()) { "Refusing an unfiltered delete of $table" }
        send(Request.Builder().url(url(table, query)).header("Prefer", "return=minimal").delete())
    }

    /**
     * Calls `rpc/[function]` and returns the raw JSON response. A function without parameters still gets
     * `{}`: the Data API rejects a bodyless POST (PGRST101).
     */
    suspend fun rpcRaw(function: String, params: JsonObject = JsonObject(emptyMap())): String =
        send(
            Request.Builder()
                .url(url("rpc/$function", PostgrestQuery()))
                .post(params.toString().toRequestBody(JSON_MEDIA)),
        )

    suspend fun <T> rpc(function: String, deserializer: KSerializer<T>, params: JsonObject = JsonObject(emptyMap())): T =
        json.decodeFromString(deserializer, rpcRaw(function, params))

    suspend inline fun <reified T> rpc(function: String, params: JsonObject = JsonObject(emptyMap())): T =
        rpc(function, serializer<T>(), params)

    private fun url(path: String, query: PostgrestQuery): HttpUrl {
        val base = baseUrl ?: throw IllegalStateException("This build is not configured to reach MoveMark’s servers.")
        val builder = base.resolvePath(path).newBuilder()
        query.params.forEach { (name, value) -> builder.addQueryParameter(name, value) }
        return builder.build()
    }

    private suspend fun send(builder: Request.Builder): String {
        val response = transport.execute(builder.header("Accept", "application/json").build())
        val body = response.bodyString()
        if (!response.isSuccessful) {
            val err = runCatching { json.parseToJsonElement(body).jsonObject }.getOrNull()
            throw PostgrestException(
                status = response.code,
                code = runCatching { err?.get("code")?.jsonPrimitive?.contentOrNull }.getOrNull(),
                serverMessage = runCatching { err?.get("message")?.jsonPrimitive?.contentOrNull }.getOrNull(),
            )
        }
        return body
    }

    private companion object {
        val JSON_MEDIA = "application/json".toMediaType()
    }
}
