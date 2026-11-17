package com.surensureshkumar.movemark.data.property

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.surensureshkumar.movemark.core.startup.RentalStatus
import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.data.cache.PropertySnapshotDao
import com.surensureshkumar.movemark.data.cache.PropertySnapshotEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * The rental gate wired end to end (real PropertyStore, Data API over a mock server, real DataStore): an offline
 * launch after an online one keeps the rental; a failed listing with nothing cached is Unavailable, never NoRental.
 * Galaxy A14 offline-onboarding P0, 2026-11-17.
 */
@RunWith(AndroidJUnit4::class)
class PropertyStoreOfflineLaunchTest {
    private val user = UUID.fromString("0000000a-0000-4000-8000-000000000001")
    private val propertyId = "11111111-0000-4000-8000-000000000001"
    private val rowJson =
        """{"id":"$propertyId","user_id":"$user","title":"Home","address_line_1":"1 Main St","city":"Toronto",""" +
            """"province_state":"ON","postal_code":"M1M1M1","country":"CA"}"""

    private lateinit var server: MockWebServer
    private lateinit var dir: File
    private lateinit var scope: CoroutineScope
    private lateinit var dataStore: DataStore<Preferences>
    private val snapshots = InMemorySnapshots()
    private var listing = "[$rowJson]"

    private class InMemorySnapshots : PropertySnapshotDao {
        val rows = mutableMapOf<String, PropertySnapshotEntity>()
        override suspend fun find(propertyId: String) = rows[propertyId]
        override suspend fun upsert(entity: PropertySnapshotEntity) { rows[entity.propertyId] = entity }
        override suspend fun clearAll() = rows.clear()
    }

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse = when {
                    request.path.orEmpty().contains("/rpc/get_property_snapshot_v2") ->
                        MockResponse().setBody("""{"property":$rowJson}""")
                    request.path.orEmpty().contains("/properties") -> MockResponse().setBody(listing)
                    else -> MockResponse().setResponseCode(404)
                }
            }
            start()
        }
        dir = File(System.getProperty("java.io.tmpdir"), "mm-store-${UUID.randomUUID()}").apply { mkdirs() }
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        dataStore = PreferenceDataStoreFactory.create(scope = scope) { File(dir, "prefs.preferences_pb") }
    }

    @After
    fun tearDown() {
        runCatching { server.shutdown() }
        scope.cancel()
        dir.deleteRecursively()
    }

    /** A fresh store over the same device storage, as after a relaunch; [base] null means the network is gone. */
    private fun store(base: HttpUrl?): PropertyStore {
        val url = base ?: HttpUrl.Builder().scheme("http").host("127.0.0.1").port(1).addPathSegments("neondb/rest/v1").build()
        val transport = AuthenticatedTransport(
            FakeTokens(),
            OkHttpClient(),
            AuthenticatedTransport.AuthOrigins(dataApiHost = url.host, apiHost = "api.invalid"),
        )
        val postgrest = PostgrestClient(url, transport)
        val storage = MoveMarkStorageService(url, transport, OkHttpClient())
        val fileUrls = StoredFileUrls(postgrest, storage)
        val repository = PropertyRepository(postgrest)
        return PropertyStore(
            propertyRepository = repository,
            inspectionRepository = InspectionRepository(ApplicationProvider.getApplicationContext(), postgrest, storage, fileUrls),
            maintenanceRepository = MaintenanceRepository(postgrest),
            hydrator = PropertyHydrator(repository, PropertySnapshotCache(snapshots), fileUrls),
            fileUrls = fileUrls,
            dataStore = dataStore,
        )
    }

    private fun online() = server.url("/neondb/rest/v1")

    @Test
    fun onlineLaunchLoadsTheRentalAndConfirmsTheListing() = runBlocking {
        val store = store(online())
        store.fetchAll(user)
        assertEquals(RentalStatus.HasRental, store.rentalStatus.value)
        assertTrue(store.listingVerified.value)
        assertNotNull(store.currentProperty.value)
    }

    @Test
    fun offlineRelaunchAfterAnOnlineOneKeepsTheRental() = runBlocking {
        store(online()).fetchAll(user)
        val offline = store(null)
        offline.fetchAll(user)
        assertEquals(RentalStatus.HasRental, offline.rentalStatus.value)
        assertFalse("a cached listing is re-read on reconnect", offline.listingVerified.value)
        assertEquals(UUID.fromString(propertyId), offline.currentProperty.value?.id)
    }

    @Test
    fun upgradeThenOfflineOpensOnTheCachedSnapshotAlone() = runBlocking {
        // A build before this one kept the active rental and its snapshot, but no listing.
        store(online()).fetchAll(user)
        dataStore.edit { it.remove(stringPreferencesKey("cached_property_listing")) }
        val offline = store(null)
        offline.fetchAll(user)
        assertEquals(RentalStatus.HasRental, offline.rentalStatus.value)
        assertEquals(UUID.fromString(propertyId), offline.currentProperty.value?.id)
    }

    @Test
    fun offlineWithNothingCachedIsUnavailableNotNoRental() = runBlocking {
        val offline = store(null)
        offline.fetchAll(user)
        assertEquals(RentalStatus.Unavailable, offline.rentalStatus.value)
        assertNull(offline.currentProperty.value)
    }

    @Test
    fun anotherAccountsCacheIsNotUsed() = runBlocking {
        store(online()).fetchAll(user)
        val offline = store(null)
        offline.fetchAll(UUID.fromString("0000000b-0000-4000-8000-000000000002"))
        assertEquals(RentalStatus.Unavailable, offline.rentalStatus.value)
        assertNull(offline.currentProperty.value)
    }

    @Test
    fun serversEmptyListingIsNoRental() = runBlocking {
        listing = "[]"
        val store = store(online())
        store.fetchAll(user)
        assertEquals(RentalStatus.NoRental, store.rentalStatus.value)
    }

    @Test
    fun reconnectConfirmsTheCachedListing() = runBlocking {
        store(online()).fetchAll(user)
        val relaunched = store(online())
        // Simulate the offline launch on this instance by loading from cache first, then reconnecting.
        relaunched.fetchAllIfUnverified(user)
        assertTrue(relaunched.listingVerified.value)
        assertEquals(RentalStatus.HasRental, relaunched.rentalStatus.value)
    }

    @Test
    fun signOutClearsTheCachedListing() = runBlocking {
        val store = store(online())
        store.fetchAll(user)
        store.clear()
        assertEquals(RentalStatus.Unknown, store.rentalStatus.value)
        val offline = store(null)
        offline.fetchAll(user)
        assertEquals(RentalStatus.Unavailable, offline.rentalStatus.value)
    }
}
