package com.surensureshkumar.movemark.data.auth

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Personal files this app keeps on the device outside the pending-evidence store: downloaded report PDFs,
 * opened supporting documents and camera working copies (all under `cacheDir`, shared through FileProvider).
 * Removed on sign-out and account deletion so they don't outlive the session on a shared phone.
 */
@Singleton
class LocalUserFiles(private val roots: List<File>) {
    @Inject constructor(@ApplicationContext context: Context) : this(FOLDERS.map { File(context.cacheDir, it) })

    fun clear() {
        roots.forEach { it.deleteRecursively() }
    }

    companion object {
        /** Must match `res/xml/file_paths.xml`. */
        val FOLDERS = listOf("movemark_reports", "movemark_documents", "movemark_captures")
    }
}
