package com.surensureshkumar.movemark.data.backend

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Headers
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** A fully read HTTP response. Bodies here are small JSON documents (never photo bytes). */
class HttpResult(
    val code: Int,
    val body: ByteArray,
    val headers: Headers,
    /** The URL that answered (after redirects); auth-rejection rules are scoped by its host. */
    val url: HttpUrl,
) {
    val isSuccessful: Boolean get() = code in 200..299
    fun bodyString(): String = body.toString(Charsets.UTF_8)
}

/** Runs [request] without blocking the caller's thread; cancelling the coroutine cancels the call. */
suspend fun OkHttpClient.send(request: Request): HttpResult {
    val call = newCall(request)
    return suspendCancellableCoroutine { cont ->
        cont.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (cont.isActive) cont.resumeWithException(e)
            }

            override fun onResponse(call: Call, response: Response) {
                val result = try {
                    response.use { HttpResult(it.code, it.body?.bytes() ?: ByteArray(0), it.headers, it.request.url) }
                } catch (e: IOException) {
                    if (cont.isActive) cont.resumeWithException(e)
                    return
                }
                cont.resume(result)
            }
        })
    }
}
