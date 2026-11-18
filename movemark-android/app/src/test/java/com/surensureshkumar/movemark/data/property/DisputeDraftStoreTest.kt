package com.surensureshkumar.movemark.data.property

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

class DisputeDraftStoreTest {
    @get:Rule val tmp = TemporaryFolder()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @After
    fun tearDown() = scope.cancel()

    @Test
    fun draftsAreKeptPerRental() = runTest {
        val store = DisputeDraftStore(PreferenceDataStoreFactory.create(scope = scope) { File(tmp.root, "t.preferences_pb") })
        val a = UUID.randomUUID()
        val b = UUID.randomUUID()
        assertNull(store.load(a))
        store.save(a, DisputeDraft("Counter deduction", "$350", listOf("r1")))
        assertEquals(DisputeDraft("Counter deduction", "$350", listOf("r1")), store.load(a))
        assertNull(store.load(b))
    }
}
