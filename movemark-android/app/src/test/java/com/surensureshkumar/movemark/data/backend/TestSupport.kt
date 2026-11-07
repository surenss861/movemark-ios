package com.surensureshkumar.movemark.data.backend

import java.util.Base64
import java.util.concurrent.atomic.AtomicInteger

/** Hands out "token-1", "token-2", … and counts refreshes. */
class FakeTokens(private var current: String = "token-1") : AccessTokenProvider {
    val refreshes = AtomicInteger(0)

    override suspend fun validAccessToken(forceRefresh: Boolean): String = current

    override suspend fun refreshedAccessToken(replacing: String): String {
        if (replacing != current) return current
        current = "token-${refreshes.incrementAndGet() + 1}"
        return current
    }
}

class InMemorySessionStorage : NeonAuthSessionStorage {
    var value: String? = null
    override fun load(): String? = value
    override fun save(value: String) { this.value = value }
    override fun clear() { value = null }
}

/** An unsigned JWT with the given lifetime; the client only reads `iat`/`exp`. */
fun fakeJwt(lifetimeSeconds: Long, tag: String = "a"): String {
    val enc = Base64.getUrlEncoder().withoutPadding()
    val header = enc.encodeToString("""{"alg":"EdDSA"}""".toByteArray())
    val payload = enc.encodeToString("""{"iat":1000,"exp":${1000 + lifetimeSeconds},"tag":"$tag"}""".toByteArray())
    return "$header.$payload.sig"
}
