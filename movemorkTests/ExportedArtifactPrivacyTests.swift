//
//  ExportedArtifactPrivacyTests.swift
//  movemorkTests
//
//  @file Owner decision D2, on generated fixtures with GPS, camera and lens fields: the original keeps every byte
//        (integrity), and what leaves the app through the document preview (Quick Look can share it) carries none of
//        that (privacy). The two are asserted separately so neither can be traded for the other.
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

@Suite struct ExportedArtifactPrivacyTests {
    private typealias F = EvidenceFixture

    /// A fixture that also names a camera, as a phone's photo does.
    private func withCamera(_ type: UTType, orientation: Int = 1) -> Data {
        let base = F.make(1200, 800, type: type, orientation: orientation)
        let src = CGImageSourceCreateWithData(base as CFData, nil)!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        var props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFMake: "FixtureMaker", kCGImagePropertyTIFFModel: "FixturePhone 1",
                                                 kCGImagePropertyTIFFSoftware: "FixtureOS 1.0", kCGImagePropertyTIFFOrientation: orientation]
        var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        exif[kCGImagePropertyExifBodySerialNumber] = "SN-0042"
        props[kCGImagePropertyExifDictionary] = exif
        CGImageDestinationAddImageFromSource(dest, src, 0, props as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    // MARK: Integrity: the original is the original

    @Test(arguments: [UTType.jpeg, .png])
    func originalEvidenceKeepsItsBytesAndMetadata(type: UTType) throws {
        let original = withCamera(type)
        let digest = sha(original)
        let source = try MMEvidenceImport.source(from: original, captureSource: .library)
        #expect(sha(source.data) == digest)  // what is uploaded as the source is byte-for-byte the file
        let p = F.properties(source.data)
        #expect(p[kCGImagePropertyGPSDictionary] != nil)
        #expect((p[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFModel] as? String == "FixturePhone 1")

        _ = MMEvidenceImport.sharedCopy(of: original)
        _ = try VaultDocumentPreviewFile.contents(for: original)
        #expect(sha(original) == digest)  // making a shareable copy never changes the input
    }

    // MARK: Privacy: what can leave the app

    @Test(arguments: [UTType.jpeg, .png])
    func sharedDocumentCopyHasNoLocationCameraOrDevice(type: UTType) throws {
        let original = withCamera(type)
        let copy = try VaultDocumentPreviewFile.contents(for: original)
        let p = F.properties(copy)
        #expect(p[kCGImagePropertyGPSDictionary] == nil)
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        #expect(tiff[kCGImagePropertyTIFFMake] == nil && tiff[kCGImagePropertyTIFFModel] == nil && tiff[kCGImagePropertyTIFFSoftware] == nil)
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifBodySerialNumber] == nil)
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(MMEvidenceImport.carriesNoIdentifyingMetadata(copy))
        for marker in ["FixtureMaker", "FixturePhone", "FixtureOS", "SN-0042", "Fixture Lens"] {
            #expect(copy.range(of: Data(marker.utf8)) == nil, "\(marker) survived in the shared copy")
        }
        // Same image: format, size and what it looks like.
        let src = CGImageSourceCreateWithData(copy as CFData, nil)!
        #expect(CGImageSourceGetType(src) as String? == type.identifier)
        #expect(F.pixelSize(copy) == F.pixelSize(original))
        #expect(F.color(copy, x: 0.25, y: 0.5).r > 200)
        #expect(F.color(copy, x: 0.75, y: 0.5).b > 200)
    }

    @Test func sharedCopyKeepsOrientationSoTheImageStillLooksUpright() throws {
        let original = withCamera(.jpeg, orientation: 6)
        let copy = try #require(MMEvidenceImport.sharedCopy(of: original))
        #expect(F.properties(copy)[kCGImagePropertyOrientation] as? Int == 6)
        #expect(F.properties(copy)[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func pdfDocumentsAreShownUnchanged() throws {
        let pdf = Data("%PDF-1.7\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n".utf8)
        #expect(try VaultDocumentPreviewFile.contents(for: pdf) == pdf)
    }

    @Test func aBrokenImageIsRefusedRatherThanSharedRaw() {
        var bytes = Data([0xFF, 0xD8, 0xFF, 0xE1])
        bytes.append(Data("Exif\0\0GPS-LEAK".utf8))
        #expect(throws: VaultDocumentPreviewFile.UncleanableImage.self) { try VaultDocumentPreviewFile.contents(for: bytes) }
    }
}
