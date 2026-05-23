package com.surensureshkumar.movemark.core.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import com.surensureshkumar.movemark.BuildConfig
import com.surensureshkumar.movemark.data.auth.ProfileRepository
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.property.PropertyRepository
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.storage.Storage
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore("movemark_prefs")

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        context.dataStore

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        val url = BuildConfig.SUPABASE_URL
        val key = BuildConfig.SUPABASE_ANON_KEY
        require(url.isNotBlank() && key.isNotBlank()) {
            "Set SUPABASE_URL and SUPABASE_ANON_KEY in movemark-android/local.properties"
        }
        return createSupabaseClient(url, key) {
            install(Auth)
            install(Postgrest)
            install(Storage)
        }
    }

    @Provides
    @Singleton
    fun providePropertyRepository(client: SupabaseClient): PropertyRepository =
        PropertyRepository(client)

    @Provides
    @Singleton
    fun provideInspectionRepository(client: SupabaseClient): InspectionRepository =
        InspectionRepository(client)

    @Provides
    @Singleton
    fun provideProfileRepository(client: SupabaseClient): ProfileRepository =
        ProfileRepository(client)

    @Provides
    @Singleton
    fun provideExportApiClient(): ExportApiClient =
        ExportApiClient(BuildConfig.MOVE_MARK_API_BASE_URL)
}
