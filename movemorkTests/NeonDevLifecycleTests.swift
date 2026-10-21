//
//  NeonDevLifecycleTests.swift
//  movemorkTests
//
//  S7 gate: the app's own auth, Data API, storage, export and RevenueCat code against the Neon `dev`
//  branch, end to end, with two real accounts. Runs inside the app host, so every call goes through the
//  shipped `NeonAuthClient` → `MoveMarkAuthenticatedTransport` → `dataAPI` / MoveMark API stack.
//
//  Opt-in (it creates and deletes real dev accounts and waits out a real 15-minute token):
//    TEST_RUNNER_MM_E2E_DIR=<dir> TEST_RUNNER_MM_E2E_PHOTO=<jpeg> TEST_RUNNER_MM_E2E_STOREKIT=<MoveMark.storekit>
//    [TEST_RUNNER_MM_E2E_REFRESH_WAIT=960] xcodebuild test …
//  The host harness answers the password-reset step by writing the emailed token to <dir>/reset-token
//  (QA addresses are not deliverable); the app never holds database credentials.
//

import Foundation
import RevenueCat
import StoreKitTest
import Testing
import UIKit
@testable import MoveMark

private let env = ProcessInfo.processInfo.environment

@MainActor
@Suite(.serialized, .enabled(if: env["MM_E2E_DIR"] != nil, "set TEST_RUNNER_MM_E2E_DIR to run against Neon dev"))
struct NeonDevLifecycleTests {
    private let dir = URL(fileURLWithPath: env["MM_E2E_DIR"] ?? "/tmp")
    private let emailA = "qa-neon-a@movemark.test"
    private let emailB = "qa-neon-b@movemark.test"

    private let properties = PropertyRepository()
    private let inspections = InspectionRepository()
    private let documents = DocumentRepository()
    private let storage = MoveMarkStorageService.shared

    /// Short id for this run, in logs and QA rental titles (the two QA emails are the authorized dev identities).
    private let runID = env["MM_E2E_RUN_ID"] ?? String(UUID().uuidString.prefix(8)).lowercased()

    private func log(_ step: String, _ detail: String = "") {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "STEP \(step)\(detail.isEmpty ? "" : " — \(detail)")\n"
        print("[\(runID)] \(line)", terminator: "")
        if let handle = try? FileHandle(forWritingTo: dir.appendingPathComponent("steps.log")) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: dir.appendingPathComponent("steps.log"))
        }
        // Last known checkpoint survives a simulator or runner death.
        try? Data("\(runID) \(stamp) \(step)\n".utf8).write(to: dir.appendingPathComponent("last-step"))
    }

    /// One lifecycle at a time: both runs would share the QA identities. O_EXCL makes the check atomic.
    private func acquireLifecycleLock() throws -> URL {
        let lock = dir.appendingPathComponent("lifecycle.lock")
        let fd = open(lock.path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
        guard fd >= 0 else {
            let holder = (try? String(contentsOf: lock, encoding: .utf8)) ?? "unknown"
            Issue.record("lifecycle already running (lock held by run \(holder)); refusing to share QA identities")
            throw NeonAuthError.invalidResponse
        }
        _ = runID.withCString { write(fd, $0, strlen($0)) }
        close(fd)
        return lock
    }

    private func jwtClaims(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return [:] }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
        return (Data(base64Encoded: b64).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
    }

    private func download(_ url: URL) async throws -> (Int, Data) {
        let (data, response) = try await URLSession.shared.data(from: url)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    private func api() throws -> ExportAPIClient {
        try ExportAPIClient(baseURLString: try #require(MoveMarkBackendConfig.apiBaseURLString))
    }

    private func waitForFile(_ name: String, seconds: Int) async throws -> String {
        let url = dir.appendingPathComponent(name)
        for _ in 0..<seconds {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            try await Task.sleep(for: .seconds(1))
        }
        throw NeonAuthError.invalidResponse
    }

    @Test(.timeLimit(.minutes(40)))
    func fullLifecycleAgainstNeonDev() async throws {
        let lock = try acquireLifecycleLock()
        defer { try? FileManager.default.removeItem(at: lock) }
        log("0 start", "run \(runID)")
        // 0. This build must point at dev and the local dev API, never production.
        let dataHost = try #require(MoveMarkBackendConfig.dataAPIURL?.host)
        let authHost = try #require(MoveMarkBackendConfig.neonAuthURL?.host)
        #expect(dataHost.hasPrefix("ep-quiet-salad-b55aeba0.") && authHost.hasPrefix("ep-quiet-salad-b55aeba0."))
        #expect(!dataHost.contains("ep-steep-wind") && MoveMarkBackendConfig.apiBaseURL?.host == "127.0.0.1")
        let photo = try Data(contentsOf: URL(fileURLWithPath: try #require(env["MM_E2E_PHOTO"])))
        let photo2 = try #require(UIImage(data: photo)?.jpegData(compressionQuality: 0.7))
        let passwordA = "Qa-\(UUID().uuidString)"
        let passwordB = "Qa-\(UUID().uuidString)"

        // 1. Create account (email/password) and finish onboarding.
        let session = SessionManager()
        await NeonAuthClient.shared.endSessionLocally(notify: false)
        let created = try await session.signUp(email: emailA, password: passwordA, confirmPassword: passwordA)
        #expect(created == .authenticated)
        #expect(session.authPhase == .needsOnboarding)
        try await session.completeOnboarding(firstName: "QA A")
        #expect(session.authPhase == .signedIn)
        let userA = try #require(session.userId)
        log("1 create account", "user \(userA.uuidString.lowercased()) → onboarding → signedIn")

        // 2. Sign out and back in; identity and profile survive, session persisted to the Keychain.
        await session.signOut()
        let storedAfterSignOut = await NeonAuthClient.shared.currentUser()
        #expect(session.authPhase == .signedOut && storedAfterSignOut == nil)
        try await session.signIn(email: emailA, password: passwordA)
        #expect(session.userId == userA && session.authPhase == .signedIn && session.firstName == "QA A")
        let relaunched = SessionManager()
        await relaunched.bootstrap()
        #expect(relaunched.userId == userA && relaunched.authPhase == .signedIn)
        log("2 sign in", "signed out → in; a fresh SessionManager restores the Keychain session")

        // 3–4. Create rental and room through the Data API (RLS as user A).
        let property = try await properties.createProperty(PropertyRow(
            id: UUID(), userId: userA, title: "QA ONLY — Neon iOS S7 run \(runID)", addressLine1: "88 Harbour St",
            city: "Toronto", provinceState: "ON", postalCode: "M5J 2N8", country: "CA"
        ))
        let room = try await properties.insertRoom(RoomRow(id: UUID(), propertyId: property.id, name: "Kitchen", sortOrder: 0))
        #expect(try await properties.fetchProperties(userId: userA).map(\.id) == [property.id])
        log("3-4 create rental + room", "property \(property.id) room \(room.id)")

        // 5. Capture/upload evidence: ticket → PUT → row with the server's path (the store's own pipeline).
        let inspection = try await inspections.upsertInspection(propertyId: property.id, userId: userA, type: "move_in")
        let item = try await inspections.insertInspectionItem(inspectionId: inspection, roomId: room.id, notes: "Kitchen\nCounters clean", conditionRating: 4)
        let saved = try await inspections.appendPhotosToInspectionItem(
            inspectionItemId: item, roomId: room.id, propertyId: property.id, userId: userA, isMoveOut: false, photos: [photo]
        )
        let kept = try #require(saved.first)
        let expectedPrefix = "\(userA.uuidString.lowercased())/\(property.id.uuidString.lowercased())/move-in/\(room.id.uuidString.lowercased())/"
        #expect(kept.filePath.hasPrefix(expectedPrefix) && kept.thumbnailPath == String(kept.filePath.dropLast(4)) + "_thumb.jpg")
        log("5 upload evidence", kept.filePath)

        // 6. Reload evidence (table read and the snapshot RPC).
        let rows = try await inspections.fetchEvidenceFiles(propertyId: property.id)
        #expect(rows.map(\.id) == [kept.id])
        let snapshot = try await PropertyStore().fetchPropertySnapshot(propertyId: property.id)
        #expect(snapshot.evidenceFiles.map(\.id) == [kept.id])
        log("6 reload evidence", "evidence_files + get_property_snapshot both return the row")

        // 7. Open original: a fresh URL by row id, byte-identical; the thumbnail too.
        let originalURL = try await inspections.signedURL(bucket: "inspection-media", path: kept.filePath)
        let (originalStatus, originalBytes) = try await download(originalURL)
        #expect(originalStatus == 200 && originalBytes == photo)
        let thumbURL = try await inspections.signedURL(bucket: "inspection-media", path: try #require(kept.thumbnailPath))
        let (thumbStatus, thumbBytes) = try await download(thumbURL)
        // The contract is pixel size, not byte size (JPEG bytes vary with content): ≤ 320px on the long side,
        // never larger than the original, and the original's bytes untouched (checked above).
        let original = try #require(UIImage(data: photo)?.cgImage)
        let thumbnail = try #require(UIImage(data: thumbBytes)?.cgImage)
        #expect(thumbStatus == 200)
        #expect(max(thumbnail.width, thumbnail.height) <= 320)
        #expect(thumbnail.width <= original.width && thumbnail.height <= original.height)
        log("7 open original", "\(originalBytes.count) bytes identical; thumbnail \(thumbnail.width)×\(thumbnail.height) from \(original.width)×\(original.height)")

        // 8. Survive token refresh: really wait out the 15-minute token, then also present the expired one.
        //    Boundaries are logged from the test side only; the app's auth code runs unchanged.
        let firstToken = try #require(await NeonAuthClient.shared.debugCachedAccessToken())
        let wait = Int(env["MM_E2E_REFRESH_WAIT"] ?? "") ?? 960
        log("8.0 token refresh", "waiting \(wait)s with the session idle")
        try await Task.sleep(for: .seconds(wait))
        log("8.1 wait complete")
        let firstExp = (jwtClaims(firstToken)["exp"] as? NSNumber)?.doubleValue ?? 0
        log("8.2 token before refresh", "cached token exp \(Int(firstExp - Date().timeIntervalSince1970))s from now (negative = expired)")
        log("8.3 refresh request started", "NeonAuthClient.validAccessToken() → GET /token with the session cookie")
        let minted = try await NeonAuthClient.shared.validAccessToken()
        log("8.4 refresh response received")
        let claims = jwtClaims(minted)
        let lifetime = ((claims["exp"] as? NSNumber)?.doubleValue ?? 0) - ((claims["iat"] as? NSNumber)?.doubleValue ?? 0)
        #expect(minted != firstToken)
        #expect((claims["sub"] as? String)?.lowercased() == userA.uuidString.lowercased())
        #expect(((claims["exp"] as? NSNumber)?.doubleValue ?? 0) > Date().timeIntervalSince1970)
        log("8.5 refreshed token validated", "new token, sub matches, lifetime \(Int(lifetime))s, not expired")
        log("8.6 authenticated request started", "Data API evidence_files")
        let afterRefresh = try await inspections.fetchEvidenceFiles(propertyId: property.id)
        #expect(afterRefresh.count == 1)
        log("8.7 authenticated request completed", "\(afterRefresh.count) row")
        await NeonAuthClient.shared.debugCacheAccessToken(firstToken) // expired: server answers 401
        log("8.8 expired token presented", "transport must refresh on 401 and retry once")
        #expect(try await inspections.fetchEvidenceFiles(propertyId: property.id).count == 1)
        _ = try await api().fetchVaultSummary(propertyId: property.id)
        let retried = try #require(await NeonAuthClient.shared.debugCachedAccessToken())
        #expect(retried != firstToken)
        log("8 token refresh passed", "proactive refresh after \(wait)s; expired token → 401 → refresh → retry succeeded (Data API + MoveMark API)")

        // 9. Delete evidence (the app deletes an evidence entry by inspection item; files go server-side).
        let item2 = try await inspections.insertInspectionItem(inspectionId: inspection, roomId: room.id, notes: "Kitchen\nScuff by door", conditionRating: 3)
        let doomed = try #require(try await inspections.appendPhotosToInspectionItem(
            inspectionItemId: item2, roomId: room.id, propertyId: property.id, userId: userA, isMoveOut: false, photos: [photo2]
        ).first)
        let doomedURL = try await inspections.signedURL(bucket: "inspection-media", path: doomed.filePath)
        #expect(try await download(doomedURL).0 == 200)
        try await inspections.deleteInspectionItem(id: item2)
        #expect(try await inspections.fetchEvidenceFiles(propertyId: property.id).map(\.id) == [kept.id])
        #expect(try await download(doomedURL).0 == 404)
        log("9 delete evidence", "row gone; object gone (presigned GET now 404); kept evidence untouched")

        // 9b. Abandon: the insert really fails → object released; the insert committed but "looked failed" → kept.
        let orphan = try await inspections.uploadEvidencePhoto(photo2, thumbnail: nil, propertyId: property.id, roomId: room.id, isMoveOut: false)
        await #expect(throws: (any Error).self) {
            _ = try await inspections.insertEvidenceFile(propertyId: property.id, inspectionItemId: UUID(), maintenanceIssueId: nil,
                                                         filePath: orphan.path, fileType: "image", capturedAt: Date())
        }
        await inspections.abandonUpload(orphan)
        let lost = try await inspections.uploadEvidencePhoto(photo2, thumbnail: nil, propertyId: property.id, roomId: room.id, isMoveOut: false)
        let lostRow = try await inspections.insertEvidenceFile(propertyId: property.id, inspectionItemId: item, maintenanceIssueId: nil,
                                                               filePath: lost.path, fileType: "image", capturedAt: Date())
        await inspections.abandonUpload(lost) // as if the insert response never arrived
        let lostURL = try await inspections.signedURL(bucket: "inspection-media", path: lost.path)
        #expect(try await download(lostURL) == (200, photo2))
        try await storage.deleteEvidence(ids: [lostRow])
        log("9b abandon", "failed insert → abandoned; committed insert + abandon → evidence kept and downloadable")

        // 10. Upload documents: a PDF lease and an image listing screenshot (with thumbnail); open; delete one.
        let leasePDF = Data("%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n".utf8)
        let lease = try await documents.uploadDocument(leasePDF, fileName: "lease.pdf", thumbnail: nil, propertyId: property.id, documentType: "lease")
        let leaseRow = PropertyDocumentRow(id: UUID(), propertyId: property.id, userId: userA, documentType: "lease",
                                           filePath: lease.path, fileName: "lease.pdf", uploadedAt: nil, metadata: nil)
        try await documents.insertDocumentRecord(leaseRow)
        let shot = try await documents.uploadDocument(photo2, fileName: "listing.jpg", thumbnail: MMImageThumbnail.make(from: photo2),
                                                      propertyId: property.id, documentType: "listing_screenshot")
        let shotRow = PropertyDocumentRow(id: UUID(), propertyId: property.id, userId: userA, documentType: "listing_screenshot",
                                          filePath: shot.path, thumbnailPath: shot.thumbnailPath, fileName: "listing.jpg", uploadedAt: nil, metadata: nil)
        try await documents.insertDocumentRecord(shotRow)
        #expect(lease.bucket == "leases" && shot.bucket == "listing-screenshots" && shot.thumbnailPath != nil)
        #expect(Set(try await documents.fetchDocuments(propertyId: property.id).map(\.id)) == [leaseRow.id, shotRow.id])
        let leaseURL = try await documents.signedURL(bucket: "leases", path: lease.path)
        #expect(try await download(leaseURL) == (200, leasePDF))
        let shotURL = try await documents.signedURL(bucket: "listing-screenshots", path: shot.path)
        try await documents.deleteDocument(id: shotRow.id)
        #expect(try await documents.fetchDocuments(propertyId: property.id).map(\.id) == [leaseRow.id])
        #expect(try await download(shotURL).0 == 404)
        log("10 documents", "lease (PDF) + listing screenshot uploaded to typed buckets, opened, screenshot deleted")

        // 11. Generate the PDF report through the API and the worker.
        let client = try api()
        let queued = try await client.requestMoveInExport(propertyId: property.id)
        var status = queued.status
        for _ in 0..<60 where status != .completed && status != .failed {
            try await Task.sleep(for: .seconds(2))
            status = try await client.fetchExports(propertyId: property.id).first { $0.id.uuidString.lowercased() == queued.exportId.lowercased() }?.status ?? status
        }
        #expect(status == .completed)
        log("11 generate PDF", "export \(queued.exportId) → \(status)")

        // 12. Download and share the report (the share sheet gets a local file, as in ExportHistoryView).
        let download12 = try await client.fetchDownloadURL(exportId: queued.exportId)
        let (pdfStatus, pdf) = try await download(try #require(URL(string: download12.downloadUrl)))
        #expect(pdfStatus == 200 && pdf.starts(with: Data("%PDF".utf8)))
        #expect(pdf.range(of: Data("/Subtype /Image".utf8)) != nil || pdf.range(of: Data("/Subtype/Image".utf8)) != nil)
        let shareFile = FileManager.default.temporaryDirectory.appendingPathComponent("MoveMark-QA-report.pdf")
        try pdf.write(to: shareFile)
        _ = UIActivityViewController(activityItems: [shareFile], applicationActivities: nil)
        #expect(FileManager.default.contents(atPath: shareFile.path) == pdf)
        log("12 download/share report", "\(pdf.count) bytes, embeds the photo; share sheet built with the local file")

        // 13. RevenueCat: same Neon id (lowercase) as the server; purchase + Restore Purchases against local
        // StoreKit test transactions (no Apple Account prompt). Entitlements stay server-authoritative (webhook).
        let storeKit = try SKTestSession(contentsOf: URL(fileURLWithPath: try #require(env["MM_E2E_STOREKIT"])))
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        let subscriptions = SubscriptionManager()
        await subscriptions.syncAuth(appUserID: session.revenueCatAppUserID)
        #expect(Purchases.isConfigured, "RevenueCat not configured: \(subscriptions.configurationErrorMessage ?? "?")")
        if Purchases.isConfigured {
            #expect(Purchases.shared.appUserID == userA.uuidString.lowercased())
            let purchase = try await storeKit.buyProduct(identifier: "monthly_subscription")
            // A system prompt must never hang the lifecycle again: give restore 90s, then record and move on.
            let restored: Bool? = await withTaskGroup(of: Bool?.self) { group in
                group.addTask { @MainActor in await subscriptions.restorePurchases(forUser: userA) }
                group.addTask { try? await Task.sleep(for: .seconds(90)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            #expect(restored != nil, "Restore Purchases did not return within 90s")
            log("13 restore purchases", "appUserID=\(Purchases.shared.appUserID) local transaction \(purchase.productID) → restored=\(restored.map(String.init(describing:)) ?? "TIMEOUT") message=\(subscriptions.lastRestoreErrorMessage ?? "none")")
        }
        storeKit.clearTransactions()

        // 14. Second user, from the app: nothing of A's is visible, signable, uploadable or deletable.
        await session.signOut()
        _ = try await session.signUp(email: emailB, password: passwordB, confirmPassword: passwordB)
        try await session.completeOnboarding(firstName: "QA B")
        let userB = try #require(session.userId)
        #expect(userB != userA)
        #expect(try await properties.fetchProperties(userId: userA).isEmpty)
        #expect(try await inspections.fetchEvidenceFiles(propertyId: property.id).isEmpty)
        #expect(try await documents.fetchDocuments(propertyId: property.id).isEmpty)
        await MoveMarkSignedURLCache.shared.removeAll()
        await #expect(throws: (any Error).self) { _ = try await inspections.signedURL(bucket: "inspection-media", path: kept.filePath) }
        await #expect(throws: (any Error).self) { _ = try await storage.downloadURLs(.evidence, ids: [kept.id]) }
        await #expect(throws: (any Error).self) {
            _ = try await inspections.uploadEvidencePhoto(photo2, thumbnail: nil, propertyId: property.id, roomId: room.id, isMoveOut: false)
        }
        try? await storage.deleteEvidence(ids: [kept.id])
        try? await storage.deleteDocuments(ids: [leaseRow.id])
        await #expect(throws: (any Error).self) { _ = try await client.fetchDownloadURL(exportId: queued.exportId) }
        await #expect(throws: (any Error).self) {
            _ = try await properties.insertRoom(RoomRow(id: UUID(), propertyId: property.id, name: "Intruder", sortOrder: 9))
        }
        try await client.deleteAccount()
        await NeonAuthClient.shared.endSessionLocally(notify: false)
        await session.signOut()
        log("14 second user", "B \(userB.uuidString.lowercased()): A's rows, files, URLs, uploads, deletes, export and room insert all refused; B deleted")

        // 15. Sign back in as A: everything B tried to delete is still there.
        try await session.signIn(email: emailA, password: passwordA)
        #expect(try await inspections.fetchEvidenceFiles(propertyId: property.id).map(\.id) == [kept.id])
        #expect(try await documents.fetchDocuments(propertyId: property.id).map(\.id) == [leaseRow.id])
        #expect(try await download(try await inspections.signedURL(bucket: "inspection-media", path: kept.filePath)).0 == 200)
        log("15 sign out/in", "A intact after B's attempts")

        // 16. Password reset: request → emailed token (host harness relays it) → new password works, old doesn't.
        try await session.sendPasswordReset(email: emailA)
        try Data(userA.uuidString.lowercased().utf8).write(to: dir.appendingPathComponent("reset-request"))
        let token = try await waitForFile("reset-token", seconds: 120)
        let newPassword = "Qa-reset-\(UUID().uuidString)"
        try await session.completePasswordReset(token: token, newPassword: newPassword, confirmPassword: newPassword)
        #expect(session.authPhase == .signedOut)
        await #expect(throws: (any Error).self) { try await session.signIn(email: emailA, password: passwordA) }
        try await session.signIn(email: emailA, password: newPassword)
        #expect(session.userId == userA)
        log("16 password reset", "token accepted; old password refused; new password signs in")

        // 17. Delete account (DELETE /api/account), then the identity is gone.
        try await api().deleteAccount()
        await NeonAuthClient.shared.endSessionLocally(notify: false)
        await session.signOut()
        await #expect(throws: (any Error).self) { try await session.signIn(email: emailA, password: newPassword) }
        try Data("\(userA.uuidString.lowercased())\n\(userB.uuidString.lowercased())".utf8).write(to: dir.appendingPathComponent("deleted-users"))
        log("17 delete account", "API deletion → sign-in refused")
    }
}
