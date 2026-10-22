//
//  MMEvidenceSaveTests.swift
//  movemorkTests
//
//  Partial-save integrity: the real upload sequence (MoveMarkStorageService: ticket → source PUT →
//  derivative/thumbnail PUT → finalize, abandon on failure) and the real MMEvidenceSaver run against a
//  stateful fake backend. One photo of a batch fails at a chosen stage; every case proves the saved
//  photos are stored exactly once, the failed one is reported, a retry sends only it, the final count is
//  right, and no ticket or object is left behind.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoveMark

// MARK: - Fake backend

/// Upload API + object store + `evidence_files`, with the server's rules: finalize needs the source and
/// derivative, a row consumes a finalized ticket once, abandon keeps a referenced upload and deletes the rest.
final class FakeEvidenceBackend: @unchecked Sendable {
    enum Stage: String, CaseIterable, Sendable {
        case ticket, sourcePut, derivativePut, thumbnailPut, finalize, insert, abandon
        /// The row commits but the response is lost (the app sees an error).
        case insertCommitsResponseLost
    }

    struct Ticket {
        var sha: String
        var state = "issued"
        var source: String, derivative: String, thumbnail: String
        var keys: [String] { [source, derivative, thumbnail] }
    }

    static let shared = FakeEvidenceBackend()
    private let lock = NSLock()
    private(set) var tickets: [String: Ticket] = [:]
    private(set) var objects: Set<String> = []
    private(set) var rows: [UUID: String] = [:]  // row id → ticket id
    private(set) var ticketRequests: [String] = []  // sha of every ticket request, in order
    private var failures: [String: [Stage: Int]] = [:]  // sha → stage → remaining failures

    func reset() {
        lock.withLock { tickets = [:]; objects = []; rows = [:]; ticketRequests = []; failures = [:] }
    }

    func fail(_ stage: Stage, for sha: String, times: Int = 1) {
        lock.withLock { failures[sha, default: [:]][stage] = times }
    }

    /// Consumes one planned failure for `stage` of the photo with `sha`.
    private func shouldFail(_ stage: Stage, _ sha: String) -> Bool {
        guard let left = failures[sha]?[stage], left > 0 else { return false }
        failures[sha]?[stage] = left - 1
        return true
    }

    // Invariants
    var ticketsStillOpen: [String] { lock.withLock { tickets.filter { ["issued", "finalized"].contains($0.value.state) }.map(\.key) } }
    var orphanObjects: Set<String> {
        lock.withLock {
            let referenced = Set(rows.values.flatMap { tickets[$0]?.keys ?? [] })
            return objects.subtracting(referenced)
        }
    }
    func rowCount(sha: String) -> Int { lock.withLock { rows.values.filter { tickets[$0]?.sha == sha }.count } }
    func ticketRequests(sha: String) -> Int { lock.withLock { ticketRequests.filter { $0 == sha }.count } }

    // Row insert (Data API + the evidence_files trigger's ticket rules).
    struct InsertError: Error {}
    func insert(rowId: UUID, upload: MoveMarkUpload) throws {
        try lock.withLock {
            guard var ticket = tickets[upload.ticketId] else { throw InsertError() }
            if shouldFail(.insert, ticket.sha) { throw InsertError() }
            guard rows[rowId] == nil, ticket.state == "finalized" else { throw InsertError() }  // primary key / ticket state
            rows[rowId] = upload.ticketId
            ticket.state = "consumed"
            tickets[upload.ticketId] = ticket
            if shouldFail(.insertCommitsResponseLost, ticket.sha) { throw InsertError() }
        }
    }

    // HTTP
    func handle(_ request: URLRequest, body: Data) -> (Int, Data) {
        lock.withLock {
            let url = request.url!
            let parts = url.path.split(separator: "/").map(String.init)
            if url.host == "objects.fake", request.httpMethod == "PUT", parts.count == 2, let ticket = tickets[parts[0]] {
                let stage: Stage = parts[1] == "source" ? .sourcePut : parts[1] == "derivative" ? .derivativePut : .thumbnailPut
                if shouldFail(stage, ticket.sha) { return (500, Data()) }
                guard ticket.state == "issued" else { return (403, Data()) }  // presigned URLs die with the ticket
                objects.insert(ticket.keys[["source", "derivative", "thumbnail"].firstIndex(of: parts[1])!])
                return (200, Data())
            }
            guard url.host == "api.fake", request.httpMethod == "POST" else { return (404, Data()) }
            switch parts {
            case ["api", "storage", "uploads"]:
                let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
                let sha = (json?["source"] as? [String: Any])?["sha256"] as? String ?? "?"
                ticketRequests.append(sha)
                if shouldFail(.ticket, sha) {  // what the API returned on the device run (PoolTimeout → 500)
                    return (500, Data(#"{"error":"Internal Server Error"}"#.utf8))
                }
                let id = UUID().uuidString.lowercased()
                tickets[id] = Ticket(sha: sha, source: "\(id)_source", derivative: "\(id).jpg", thumbnail: "\(id)_thumb.jpg")
                let t = tickets[id]!
                func part(_ key: String, _ name: String) -> [String: Any] {
                    ["path": key, "url": "https://objects.fake/\(id)/\(name)", "headers": [String: String]()]
                }
                var ticketJSON = part(t.derivative, "derivative")
                ticketJSON["uploadTicketId"] = id
                ticketJSON["bucket"] = "inspection-media"
                ticketJSON["thumbnail"] = part(t.thumbnail, "thumbnail")
                ticketJSON["source"] = part(t.source, "source")
                return (200, try! JSONSerialization.data(withJSONObject: ticketJSON))
            case let p where p.count == 5 && p[3] != "" && p[4] == "finalize":
                guard var ticket = tickets[p[3]] else { return (404, Data()) }
                if shouldFail(.finalize, ticket.sha) { return (500, Data()) }
                guard objects.contains(ticket.source), objects.contains(ticket.derivative) else { return (409, Data()) }
                ticket.state = "finalized"
                tickets[p[3]] = ticket
                let body: [String: Any] = ["status": "finalized", "thumbnail": objects.contains(ticket.thumbnail)]
                return (200, try! JSONSerialization.data(withJSONObject: body))
            case let p where p.count == 5 && p[4] == "abandon":
                guard var ticket = tickets[p[3]] else { return (404, Data()) }
                if shouldFail(.abandon, ticket.sha) { return (500, Data()) }
                if rows.values.contains(p[3]) { return (200, Data(#"{"status":"kept"}"#.utf8)) }
                objects.subtract(ticket.keys)
                ticket.state = "abandoned"
                tickets[p[3]] = ticket
                return (200, Data(#"{"status":"deleted"}"#.utf8))
            default:
                return (404, Data())
            }
        }
    }
}

final class FakeEvidenceURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                body.append(buffer, count: n)
            }
        }
        let request = self.request
        // Answer asynchronously, as a network would: completing inside startLoading() crashes async data(for:).
        DispatchQueue.global().async { [self] in
            let (status, data) = FakeEvidenceBackend.shared.handle(request, body: body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeEvidenceURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Tests

@Suite(.serialized) struct MMEvidenceSaveTests {
    private let backend = FakeEvidenceBackend.shared
    /// Three distinct photos (distinct bytes, so distinct SHA-256), the middle one is the one that fails.
    private let photos: [MMEvidenceSource] = [(900, 600), (640, 480), (500, 700)].map {
        try! MMEvidenceImport.source(from: EvidenceFixture.make($0.0, $0.1), captureSource: .library)
    }
    private var failing: MMEvidenceSource { photos[1] }

    private var saver: MMEvidenceSaver {
        let session = FakeEvidenceURLProtocol.makeSession()
        let storage = MoveMarkStorageService(
            apiTransport: { try await session.data(for: $0) },
            objectSession: session,
            apiBaseURL: { URL(string: "https://api.fake") }
        )
        let backend = backend
        let ids = (UUID(), UUID())
        return MMEvidenceSaver(
            upload: { try await storage.uploadEvidence($0, propertyId: ids.0, roomId: ids.1, isMoveOut: false) },
            insert: { rowId, upload in try backend.insert(rowId: rowId, upload: upload) },
            abandon: { await storage.abandon($0) }
        )
    }

    private func pending() -> [MMPendingEvidence] { photos.map { MMPendingEvidence(source: $0) } }

    /// Every photo stored exactly once, nothing left open or unreferenced.
    private func expectCleanAndComplete(_ sources: [MMEvidenceSource], sourceLocation: SourceLocation = #_sourceLocation) {
        for source in sources {
            #expect(backend.rowCount(sha: source.sha256Hex) == 1, "rows for one photo", sourceLocation: sourceLocation)
        }
        #expect(backend.ticketsStillOpen.isEmpty, "open tickets", sourceLocation: sourceLocation)
        #expect(backend.orphanObjects.isEmpty, "unreferenced objects", sourceLocation: sourceLocation)
    }

    @Test(arguments: [FakeEvidenceBackend.Stage.ticket, .sourcePut, .derivativePut, .finalize, .insert])
    func oneFailedPhotoIsReportedAndRetriedAlone(stage: FakeEvidenceBackend.Stage) async throws {
        backend.reset()
        backend.fail(stage, for: failing.sha256Hex)

        let first = await saver.save(pending())
        #expect(!first.isComplete)
        #expect(first.saved.count == 2 && first.requestedCount == 3)
        #expect(first.pending.map(\.source) == [failing])
        #expect(first.pending[0].unresolved == nil)  // its ticket (if any) was released
        #expect(MMEvidenceSaveStatus.partial(saved: first.saved.count, requested: first.requestedCount)
                == "2 of 3 photos saved. 1 photo needs retry.")
        // The failure left nothing behind, and the two good photos are stored once each.
        #expect(backend.ticketsStillOpen.isEmpty && backend.orphanObjects.isEmpty)
        #expect(backend.rowCount(sha: photos[0].sha256Hex) == 1 && backend.rowCount(sha: photos[2].sha256Hex) == 1)
        #expect(backend.rowCount(sha: failing.sha256Hex) == 0)

        let requestsBefore = photos.map { backend.ticketRequests(sha: $0.sha256Hex) }
        let retry = await saver.save(first.pending)
        #expect(retry.isComplete && retry.saved.count == 1 && retry.saved[0].id == first.pending[0].id)
        // Only the failed photo was sent again.
        #expect(backend.ticketRequests(sha: photos[0].sha256Hex) == requestsBefore[0])
        #expect(backend.ticketRequests(sha: photos[2].sha256Hex) == requestsBefore[2])
        #expect(backend.ticketRequests(sha: failing.sha256Hex) == requestsBefore[1] + 1)
        #expect(first.saved.count + retry.saved.count == 3)
        expectCleanAndComplete(photos)
    }

    @Test func thumbnailFailureStillSavesThePhotoWithoutAThumbnail() async {
        backend.reset()
        backend.fail(.thumbnailPut, for: failing.sha256Hex)
        let result = await saver.save(pending())
        #expect(result.isComplete && result.saved.count == 3)
        #expect(result.saved[1].thumbnailPath == nil && result.saved[0].thumbnailPath != nil)
        expectCleanAndComplete(photos)
    }

    /// The device run's failure: the API couldn't reach the database (PoolTimeout → 500) for one photo.
    @Test func transientServerErrorOnOnePhotoThenRecovery() async {
        backend.reset()
        backend.fail(.ticket, for: failing.sha256Hex, times: 2)  // still down on the first retry
        let first = await saver.save(pending())
        #expect(first.saved.count == 2 && first.pending.count == 1)
        let stillDown = await saver.save(first.pending)
        #expect(stillDown.saved.isEmpty && stillDown.pending.map(\.id) == first.pending.map(\.id))
        let recovered = await saver.save(stillDown.pending)
        #expect(recovered.isComplete && recovered.saved.map(\.id) == first.pending.map(\.id))
        expectCleanAndComplete(photos)
    }

    /// Outage mid-upload: finalize fails and so does the abandon. The upload stays attached to the photo
    /// and is released before the photo is uploaded again — no orphaned objects, no duplicate.
    @Test func failedAbandonIsSettledBeforeReupload() async {
        backend.reset()
        backend.fail(.finalize, for: failing.sha256Hex)
        backend.fail(.abandon, for: failing.sha256Hex)
        let first = await saver.save(pending())
        #expect(first.saved.count == 2 && first.pending.count == 1)
        #expect(first.pending[0].unresolved != nil)
        #expect(backend.ticketsStillOpen.count == 1)  // outstanding until the retry settles it
        let retry = await saver.save(first.pending)
        #expect(retry.isComplete)
        expectCleanAndComplete(photos)
    }

    /// The row committed but the response was lost: abandon answers `kept`, so the photo counts as saved
    /// at once and is never uploaded again.
    @Test func committedRowWithLostResponseCountsAsSaved() async {
        backend.reset()
        backend.fail(.insertCommitsResponseLost, for: failing.sha256Hex)
        let result = await saver.save(pending())
        #expect(result.isComplete && result.saved.count == 3)
        #expect(backend.ticketRequests(sha: failing.sha256Hex) == 1)
        expectCleanAndComplete(photos)
    }

    /// Same, but the abandon that would have told us also fails: the photo stays pending with its upload,
    /// and the retry learns it was saved (`kept`) without uploading it again.
    @Test func lostCommitWithFailedAbandonIsResolvedOnRetryWithoutDuplicate() async {
        backend.reset()
        backend.fail(.insertCommitsResponseLost, for: failing.sha256Hex)
        backend.fail(.abandon, for: failing.sha256Hex)
        let first = await saver.save(pending())
        #expect(first.saved.count == 2 && first.pending.count == 1 && first.pending[0].unresolved != nil)
        #expect(backend.rowCount(sha: failing.sha256Hex) == 1)  // it is in fact stored
        let retry = await saver.save(first.pending)
        #expect(retry.isComplete && retry.saved.map(\.id) == first.pending.map(\.id))
        #expect(backend.ticketRequests(sha: failing.sha256Hex) == 1)  // never re-uploaded
        expectCleanAndComplete(photos)
    }

    @Test func completeSuccess() async {
        backend.reset()
        let batch = pending()
        let result = await saver.save(batch)
        #expect(result.isComplete && result.saved.count == 3 && result.pending.isEmpty)
        #expect(result.saved.map(\.id) == batch.map(\.id))  // the row ids chosen up front, in request order
        expectCleanAndComplete(photos)
    }

    @Test func completeFailureSavesNothingAndClaimsNothing() async {
        backend.reset()
        for photo in photos { backend.fail(.ticket, for: photo.sha256Hex) }
        let first = await saver.save(pending())
        #expect(first.saved.isEmpty && first.pending.count == 3 && !first.isComplete)
        #expect(MMEvidenceSaveStatus.partial(saved: 0, requested: 3) == "No photos were saved. 3 photos need retry.")
        #expect(backend.rows.isEmpty && backend.objects.isEmpty)
        let retry = await saver.save(first.pending)
        #expect(retry.isComplete && retry.saved.count == 3)
        expectCleanAndComplete(photos)
    }

    @Test func statusLineWording() {
        #expect(MMEvidenceSaveStatus.partial(saved: 1, requested: 2) == "1 of 2 photos saved. 1 photo needs retry.")
        #expect(MMEvidenceSaveStatus.partial(saved: 1, requested: 4) == "1 of 4 photos saved. 3 photos need retry.")
    }
}
