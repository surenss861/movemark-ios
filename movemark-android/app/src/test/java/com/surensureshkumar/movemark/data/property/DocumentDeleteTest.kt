package com.surensureshkumar.movemark.data.property

import com.surensureshkumar.movemark.data.backend.AuthenticatedTransport
import com.surensureshkumar.movemark.data.backend.FakeTokens
import com.surensureshkumar.movemark.data.backend.MoveMarkStorageService
import com.surensureshkumar.movemark.data.backend.PostgrestClient
import com.surensureshkumar.movemark.data.backend.StoredFileUrls
import com.surensureshkumar.movemark.domain.VaultDocumentKind
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Collections
import java.util.UUID

class DocumentDeleteTest {
    private lateinit var server: MockWebServer
    private lateinit var repo: DocumentRepository
    private val requests = Collections.synchronizedList(mutableListOf<Pair<RecordedRequest, String>>())
    private var documentsJson = "[]"

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse {
                    requests += request to request.body.readUtf8()
                    return when {
                        request.path!!.startsWith("/rest/v1/property_documents") -> MockResponse().setBody(documentsJson)
                        request.path == "/api/storage/documents" -> MockResponse().setResponseCode(204)
                        else -> MockResponse().setResponseCode(404)
                    }
                }
            }
            start()
        }
        val transport = AuthenticatedTransport(FakeTokens(), OkHttpClient(), AuthenticatedTransport.AuthOrigins(server.hostName, server.hostName))
        val postgrest = PostgrestClient(server.url("/rest/v1"), transport)
        val storage = MoveMarkStorageService(server.url("/"), transport, OkHttpClient())
        repo = DocumentRepository(postgrest, storage, StoredFileUrls(postgrest, storage)) { false }
    }

    @After
    fun tearDown() = server.shutdown()

    private fun row(id: String, type: String) =
        """{"id":"$id","property_id":"p","user_id":"u","document_type":"$type","file_path":"f/$id.pdf","file_name":"$id.pdf"}"""

    @Test
    fun deletesEveryCopyOfTheTypeIncludingLegacySpellingsAndNothingElse() = runTest {
        documentsJson = "[${row("a", "deposit_receipt")},${row("b", "deposit-receipt")},${row("c", "lease")}]"
        repo.deleteDocuments(UUID.randomUUID(), VaultDocumentKind.DepositReceipt)
        val delete = requests.single { it.first.method == "DELETE" }
        assertEquals("/api/storage/documents", delete.first.path)
        assertTrue(delete.second.contains("\"a\"") && delete.second.contains("\"b\""))
        assertTrue(!delete.second.contains("\"c\""))
    }

    @Test
    fun nothingOnFileSendsNoDelete() = runTest {
        documentsJson = "[${row("c", "lease")}]"
        repo.deleteDocuments(UUID.randomUUID(), VaultDocumentKind.DepositReceipt)
        assertTrue(requests.none { it.first.method == "DELETE" })
    }
}
