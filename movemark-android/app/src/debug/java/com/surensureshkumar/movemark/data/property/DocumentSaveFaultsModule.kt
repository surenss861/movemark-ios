package com.surensureshkumar.movemark.data.property

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent

/**
 * Debug-only. Set `fail_next_document_insert` in the `movemark_debug` prefs to make the next
 * document record insert fail after upload, exercising storage cleanup and safe Replace.
 */
@Module
@InstallIn(SingletonComponent::class)
object DocumentSaveFaultsModule {
    private const val DEBUG_PREFS = "movemark_debug"
    private const val FAIL_NEXT_INSERT = "fail_next_document_insert"

    @Provides
    fun provideDocumentSaveFaults(@ApplicationContext context: Context): DocumentSaveFaults =
        DocumentSaveFaults {
            val prefs = context.getSharedPreferences(DEBUG_PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(FAIL_NEXT_INSERT, false)) return@DocumentSaveFaults false
            prefs.edit().putBoolean(FAIL_NEXT_INSERT, false).apply()
            true
        }
}
