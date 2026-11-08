//
//  TeenPhotoPrivacyTests.swift
//  movemorkTests
//
//  @file Option B: a teen account's photos lose location and identifying metadata before anything is stored, keeping
//        the capture date and orientation; adults keep their originals byte-for-byte. Also the off-main pipeline
//        (each helper is called from the main actor here; Debug builds trap if one ever runs on the main thread) and
//        the Sentry start rule.
//  @domain evidence
//  @status stable
//

import CryptoKit
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import MoveMark

@MainActor
@Suite(.serialized) struct TeenPhotoPrivacyTests {
    private typealias F = EvidenceFixture

    /// A phone-like photo: GPS, make/model/software, serial, owner, lens, IPTC city, and XMP location.
    private func phonePhoto(_ type: UTType, orientation: Int = 6) -> Data {
        let base = F.make(1200, 800, type: type, orientation: orientation)
        let src = CGImageSourceCreateWithData(base as CFData, nil)!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        var props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFMake: "TEENMAKE", kCGImagePropertyTIFFModel: "TEENMODEL",
                                                 kCGImagePropertyTIFFSoftware: "TEENSOFT", kCGImagePropertyTIFFOrientation: orientation]
        var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        exif[kCGImagePropertyExifBodySerialNumber] = "TEENSERIAL"
        exif[kCGImagePropertyExifCameraOwnerName] = "TEENOWNER"
        props[kCGImagePropertyExifDictionary] = exif
        props[kCGImagePropertyIPTCDictionary] = [kCGImagePropertyIPTCCity: "TEENCITY"]
        let xmp = CGImageMetadataCreateMutable()
        CGImageMetadataRegisterNamespaceForPrefix(xmp, "http://ns.adobe.com/photoshop/1.0/" as CFString, "photoshop" as CFString, nil)
        CGImageMetadataSetValueWithPath(xmp, nil, "photoshop:City" as CFString, "TEENXMPCITY" as CFString)
        CGImageDestinationAddImageAndMetadata(dest, CGImageSourceCreateImageAtIndex(src, 0, nil)!, xmp, props as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func assertTeenSafe(_ data: Data, sourceOrientation: Int, file: String = #fileID) {
        let p = F.properties(data)
        #expect(p[kCGImagePropertyGPSDictionary] == nil)
        #expect(p[kCGImagePropertyIPTCDictionary] == nil || (p[kCGImagePropertyIPTCDictionary] as? [CFString: Any])?.isEmpty == true)
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        #expect(tiff[kCGImagePropertyTIFFMake] == nil && tiff[kCGImagePropertyTIFFModel] == nil && tiff[kCGImagePropertyTIFFSoftware] == nil)
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifBodySerialNumber] == nil && exif[kCGImagePropertyExifCameraOwnerName] == nil)
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:01 09:15:00")  // when is kept
        #expect(MMEvidenceImport.carriesNoIdentifyingMetadata(data, allowCaptureDate: true))
        for marker in ["TEENMAKE", "TEENMODEL", "TEENSOFT", "TEENSERIAL", "TEENOWNER", "TEENCITY", "TEENXMPCITY", "Fixture Lens"] {
            #expect(data.range(of: Data(marker.utf8)) == nil, "\(marker) survived")
        }
        // Upright either way: orientation kept as a tag (lossless) or applied to the pixels (HEIC → JPEG).
        let orientation = p[kCGImagePropertyOrientation] as? Int ?? 1
        #expect(orientation == sourceOrientation || orientation == 1)
    }

    @Test(arguments: [UTType.jpeg, .png])
    func teenJPEGAndPNGKeepFormatAndPixelsWithoutIdentifyingMetadata(type: UTType) throws {
        let photo = phonePhoto(type)
        let source = try MMEvidenceImport.source(from: photo, captureSource: .library, privacy: .teen)
        #expect(source.mimeType == (type == .jpeg ? "image/jpeg" : "image/png"))
        #expect((source.pixelWidth, source.pixelHeight) == (1200, 800))
        #expect(source.sha256Hex == SHA256.hash(data: source.data).map { String(format: "%02x", $0) }.joined())  // hash of what's stored
        #expect(source.capturedAt != nil)
        assertTeenSafe(source.data, sourceOrientation: 6)
    }

    @Test func teenHEICBecomesAFullResolutionJPEG() throws {
        let source = try MMEvidenceImport.source(from: phonePhoto(.heic), captureSource: .library, privacy: .teen)
        #expect(source.mimeType == "image/jpeg")
        #expect(max(source.pixelWidth, source.pixelHeight) == 1200)
        assertTeenSafe(source.data, sourceOrientation: 6)
    }

    @Test func teenStrippingIsIdempotent() throws {
        let once = try MMEvidenceImport.teenSafe(phonePhoto(.jpeg))
        #expect(try MMEvidenceImport.teenSafe(once) == once)
    }

    @Test(arguments: [UTType.jpeg, .png, .heic])
    func adultsKeepTheOriginalByteForByte(type: UTType) throws {
        let photo = phonePhoto(type)
        let source = try MMEvidenceImport.source(from: photo, captureSource: .library, privacy: .standard)
        #expect(source.data == photo)
        #expect(F.properties(source.data)[kCGImagePropertyGPSDictionary] != nil)
    }

    @Test func aPhotoQueuedBeforeTheRuleWasKnownIsStrippedAtUpload() async throws {
        let queued = try MMEvidenceImport.source(from: phonePhoto(.jpeg), captureSource: .camera, privacy: .standard)
        let prepared = try await MMEvidenceImport.prepareForUpload(queued, privacy: .teen)
        assertTeenSafe(prepared.source.data, sourceOrientation: 6)
        #expect(prepared.source.captureSource == .camera)
        assertTeenSafe(prepared.derivative, sourceOrientation: 1)
        #expect(prepared.thumbnail.map { MMEvidenceImport.carriesNoIdentifyingMetadata($0) } == true)
    }

    @Test func adultUploadPreparationIsByteCompatibleWithBefore() async throws {
        let source = try MMEvidenceImport.source(from: phonePhoto(.jpeg), captureSource: .library, privacy: .standard)
        let prepared = try await MMEvidenceImport.prepareForUpload(source, privacy: .standard)
        #expect(prepared.source == source)
        #expect(prepared.derivative == MMEvidenceImport.derivative(from: source))
        #expect(prepared.thumbnail == MMEvidenceImport.thumbnail(from: source))
    }

    @Test func teenDocumentsAreStrippedAndAdultDocumentsKeepTheirBytes() async throws {
        let photo = phonePhoto(.jpeg)
        let teen = try await MMEvidenceImport.documentImage(photo, privacy: .teen)
        assertTeenSafe(teen.bytes, sourceOrientation: 6)
        let adult = try await MMEvidenceImport.documentImage(photo, privacy: .standard)
        #expect(adult.bytes == photo && adult.fileExtension == "jpg")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("teen-doc-\(UUID()).jpg")
        try photo.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        assertTeenSafe(try await MMEvidenceImport.documentFile(at: url, privacy: .teen), sourceOrientation: 6)
        #expect(try await MMEvidenceImport.documentFile(at: url, privacy: .standard) == photo)
    }

    /// Every helper is awaited from the main actor here; in Debug each traps on the main thread, so reaching the end
    /// means the work ran off the main actor.
    @Test func imageWorkRunsOffTheMainActor() async throws {
        #expect(Thread.isMainThread)
        let photo = phonePhoto(.jpeg)
        _ = try await MMEvidenceImport.sourceOffMain(from: photo, captureSource: .library, privacy: .standard)
        _ = try await MMEvidenceImport.librarySelectionItem(photo, privacy: .teen)
        _ = try await MMEvidenceImport.documentImage(photo, privacy: .standard)
        _ = try await MMEvidenceImport.previewFileContents(photo)
        let source = try MMEvidenceImport.source(from: photo, captureSource: .library, privacy: .standard)
        _ = try await MMEvidenceImport.prepareForUpload(source, privacy: .standard)
    }

    @Test func thePolicyIsPerAccountAndSurvivesARelaunch() {
        let teen = UUID(), adult = UUID()
        let policy = MMPhotoPrivacyPolicy.shared
        defer {
            policy.reset()
            UserDefaults.standard.removeObject(forKey: "MoveMarkPhotoPrivacy.\(teen.uuidString.lowercased())")
            UserDefaults.standard.removeObject(forKey: "MoveMarkPhotoPrivacy.\(adult.uuidString.lowercased())")
        }
        policy.apply(serverCategory: "teen", userId: teen)
        #expect(policy.current == .teen)
        policy.apply(serverCategory: "adult", userId: adult)
        #expect(policy.current == .standard)
        policy.restore(userId: teen)
        #expect(policy.current == .teen)
        policy.apply(serverCategory: nil, userId: teen)  // no answer from the server: keep what this account had
        #expect(policy.current == .teen)
        policy.reset()
        #expect(policy.current == .standard)
        #expect(ProofSavedReceiptModel(roomName: "K", photoCount: 1, savedAt: .now, primaryActionLabel: "x").metadataRemovedForPrivacy == false)
        policy.set(.teen)
        #expect(ProofSavedReceiptModel(roomName: "K", photoCount: 1, savedAt: .now, primaryActionLabel: "x").metadataRemovedForPrivacy == true)
    }
}

// MARK: - The age-range question

struct LegalAgeRangeTests {
    @Test func rangesMapToWhatTheServerRecords() {
        #expect(LegalAgeChoice.under13.band(livesInQuebec: nil) == nil)
        #expect(LegalAgeChoice.thirteen.band(livesInQuebec: nil) == nil)    // Quebec question unanswered
        #expect(LegalAgeChoice.thirteen.band(livesInQuebec: true) == nil)   // 13 in Quebec: Phase 2
        #expect(LegalAgeChoice.thirteen.band(livesInQuebec: false) == .teen)
        #expect(LegalAgeChoice.fourteenToSeventeen.band(livesInQuebec: nil) == .teen)
        #expect(LegalAgeChoice.adult.band(livesInQuebec: nil) == .adult)
        #expect(LegalAgeChoice.under13.isUnavailable(livesInQuebec: nil))
        #expect(LegalAgeChoice.thirteen.isUnavailable(livesInQuebec: true))
        #expect(!LegalAgeChoice.thirteen.isUnavailable(livesInQuebec: false))
    }

    private func status(_ json: String) throws -> LegalStatus { try JSONDecoder().decode(LegalStatus.self, from: Data(json.utf8)) }
    private let docs = #""documents":{"terms":{"version":"t1","url":null},"privacy_notice":{"version":"p1","url":null}}"#

    @Test func theRangeQuestionSendsTheFiveArgumentCall() throws {
        let s = try status(#"{"enforced":false,"acceptance_required":true,"blocked":false,"age_requirement":"bands_v1","age_category":null,\#(docs)}"#)
        #expect(s.age == .ageRange)
        #expect(LegalAcceptanceCall.make(for: s, method: .email, band: nil) == nil)  // no eligible range: nothing is sent
        #expect(LegalAcceptanceCall.make(for: s, method: .google, band: .teen) == .withAgeBand(
            LegalAcceptanceWithBandParams(p_method: "google", p_terms_version: "t1", p_privacy_notice_version: "p1",
                                          p_age_attestation: "bands_v1", p_age_band: "13_17")))
        let body = try JSONEncoder().encode(LegalAcceptanceWithBandParams(p_method: "e", p_terms_version: "t", p_privacy_notice_version: "p",
                                                                         p_age_attestation: "bands_v1", p_age_band: "18_plus"))
        #expect(try #require(JSONSerialization.jsonObject(with: body) as? [String: String]).keys.sorted()
                == ["p_age_attestation", "p_age_band", "p_method", "p_privacy_notice_version", "p_terms_version"])
    }

    @Test func theAccountCategoryIsDecoded() throws {
        let s = try status(#"{"enforced":true,"acceptance_required":false,"blocked":false,"age_requirement":"bands_v1","age_category":"teen",\#(docs)}"#)
        #expect(s.ageCategory == "teen")
    }

    @MainActor
    @Test func theRangeScreenWontContinueWithoutAnEligibleAnswer() {
        #expect(!LegalAcceptanceScreen(termsURL: nil, privacyURL: nil, age: .ageRange).canContinue)
    }
}

// MARK: - Sentry

struct CrashReportingStartTests {
    @Test func onlyReleaseBuildsOutsideTestsStartSentry() {
        #expect(MoveMarkCrashReporting.shouldStart(isDebugBuild: false, environment: [:], arguments: []))
        #expect(!MoveMarkCrashReporting.shouldStart(isDebugBuild: true, environment: [:], arguments: []))
        #expect(!MoveMarkCrashReporting.shouldStart(isDebugBuild: false, environment: ["XCTestConfigurationFilePath": "/x"], arguments: []))
        #expect(!MoveMarkCrashReporting.shouldStart(isDebugBuild: false, environment: ["XCTestSessionIdentifier": "1"], arguments: []))
        #expect(!MoveMarkCrashReporting.shouldStart(isDebugBuild: false, environment: [:], arguments: ["-MoveMarkUITest"]))
        // This very test process: a Debug build under XCTest.
        #expect(!MoveMarkCrashReporting.shouldStart(isDebugBuild: MoveMarkCrashReporting.isDebugBuild,
                                                    environment: ProcessInfo.processInfo.environment, arguments: ProcessInfo.processInfo.arguments))
    }
}
