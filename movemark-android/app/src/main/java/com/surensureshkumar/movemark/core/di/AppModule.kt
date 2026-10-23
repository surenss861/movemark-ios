package com.surensureshkumar.movemark.core.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import com.surensureshkumar.movemark.BuildConfig
import com.surensureshkumar.movemark.data.cache.MoveMarkDatabase
import com.surensureshkumar.movemark.data.cache.PropertySnapshotDao
import com.surensureshkumar.movemark.data.property.DocumentRepository
import com.surensureshkumar.movemark.data.property.DocumentSaveFaults
import com.surensureshkumar.movemark.data.property.InspectionRepository
import com.surensureshkumar.movemark.data.remote.ExportApiClient
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.BackendConfig
import com.surensureshkumar.movemark.data.backend.KeystoreNeonAuthSessionStorage
import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.NeonAuthClient
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import okhttp3.OkHttpClient
import javax.inject.Named
import java.util.concurrent.TimeUnit
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
    fun provideBackendConfig(): BackendConfig = BackendConfig.from(
        neonAuthUrl = BuildConfig.NEON_AUTH_URL,
        dataApiUrl = BuildConfig.NEON_DATA_API_URL,
        apiBaseUrl = BuildConfig.MOVEMARK_API_BASE_URL,
    )

    /** Neon Auth, Data API and MoveMark API. No cookie jar: the session cookie is attached by hand, to auth only. */
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(90, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

    /** Presigned object-storage PUTs: no cookies, no auth header, room for a 25 MB source. */
    @Provides
    @Singleton
    @Named("objectStorage")
    fun provideObjectStorageHttpClient(client: OkHttpClient): OkHttpClient =
        client.newBuilder()
            .readTimeout(120, TimeUnit.SECONDS)
            .writeTimeout(120, TimeUnit.SECONDS)
            .build()

    @Provides
    @Singleton
    fun provideNeonAuthClient(
        @ApplicationContext context: Context,
        config: BackendConfig,
        client: OkHttpClient,
    ): NeonAuthClient = NeonAuthClient(config.neonAuthUrl, client, KeystoreNeonAuthSessionStorage(context))

    @Provides
    @Singleton
    fun provideAuthenticatedTransport(
        auth: NeonAuthClient,
        config: BackendConfig,
        client: OkHttpClient,
    ): AuthenticatedTransport = AuthenticatedTransport(auth, client, AuthenticatedTransport.AuthOrigins.from(config))

    @Provides
    @Singleton
    fun providePostgrestClient(config: BackendConfig, transport: AuthenticatedTransport): PostgrestClient =
        PostgrestClient(config.dataApiUrl, transport)

    @Provides
    @Singleton
    fun provideStorageService(
        config: BackendConfig,
        transport: AuthenticatedTransport,
        @Named("objectStorage") objectClient: OkHttpClient,
    ): MoveMarkStorageService = MoveMarkStorageService(config.apiBaseUrl, transport, objectClient)

    @Provides
    @Singleton
    fun provideStoredFileUrls(postgrest: PostgrestClient, storage: MoveMarkStorageService): StoredFileUrls =
        StoredFileUrls(postgrest, storage)

    @Provides
    @Singleton
    fun provideMoveMarkDatabase(@ApplicationContext context: Context): MoveMarkDatabase =
        Room.databaseBuilder(context, MoveMarkDatabase::class.java, "movemark_cache.db")
            // This is a best-effort local cache of server data (not a source of truth), so wiping
            // it on a schema bump is fine -- it just repopulates on the next successful hydrate.
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    @Singleton
    fun providePropertySnapshotDao(database: MoveMarkDatabase): PropertySnapshotDao =
        database.propertySnapshotDao()

    @Provides
    @Singleton
    fun provideInspectionRepository(
        @ApplicationContext context: Context,
        postgrest: PostgrestClient,
        storage: MoveMarkStorageService,
        fileUrls: StoredFileUrls,
    ): InspectionRepository = InspectionRepository(context, postgrest, storage, fileUrls)

    @Provides
    @Singleton
    fun provideDocumentRepository(
        postgrest: PostgrestClient,
        storage: MoveMarkStorageService,
        fileUrls: StoredFileUrls,
        saveFaults: DocumentSaveFaults,
    ): DocumentRepository = DocumentRepository(postgrest, storage, fileUrls, saveFaults)

    @Provides
    @Singleton
    fun provideExportApiClient(config: BackendConfig, transport: AuthenticatedTransport): ExportApiClient =
        ExportApiClient(config.apiBaseUrl, transport)
}
