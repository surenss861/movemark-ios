package com.surensureshkumar.movemark.data.backend

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Where [NeonAuthClient] keeps the session (cookie + user) between launches. */
interface NeonAuthSessionStorage {
    fun load(): String?
    fun save(value: String)
    fun clear()
}

/**
 * The session as one value, AES-256-GCM encrypted under a non-exportable Android Keystore key and stored
 * in app-private preferences (the iOS build keeps it in the Keychain, this device only). A value that can't
 * be decrypted — e.g. restored from a backup onto another device, whose Keystore never had the key — is
 * dropped, which simply means signing in again.
 */
class KeystoreNeonAuthSessionStorage(context: Context) : NeonAuthSessionStorage {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun load(): String? {
        val stored = prefs.getString(KEY, null) ?: return null
        return runCatching {
            val raw = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw, 0, IV_BYTES))
            String(cipher.doFinal(raw, IV_BYTES, raw.size - IV_BYTES), Charsets.UTF_8)
        }.onFailure {
            Log.w(TAG, "stored session unreadable; signing out locally")
            clear()
        }.getOrNull()
    }

    override fun save(value: String) {
        runCatching {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key())
            val sealed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            prefs.edit().putString(KEY, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
        }.onFailure { Log.e(TAG, "session save failed", it) }
    }

    override fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val TAG = "NeonAuthStorage"
        const val PREFS = "movemark_neon_auth"
        const val KEY = "session"
        const val ALIAS = "movemark_neon_auth_session"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_BYTES = 12
    }
}
