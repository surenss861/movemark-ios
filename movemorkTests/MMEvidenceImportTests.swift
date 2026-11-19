//
//  MMEvidenceImportTests.swift
//  movemorkTests
//
//  The evidence contract, on generated fixtures with known size, orientation, capture date and GPS:
//  sources are the exact bytes and real type; derivatives/thumbnails never upscale, never crop, keep
//  the aspect ratio, come out upright, drop GPS, keep (only) the capture date; nothing depends on the
//  display scale. Colour bands in the fixtures make a crop or a wrong rotation visible in pixels.
//

import CryptoKit
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import MoveMark

enum EvidenceFixture {
    /// Red left half, blue right half, green band along the top 10% (as displayed when orientation = 1).
    static func make(_ w: Int, _ h: Int, type: UTType = .jpeg, orientation: Int = 1, date: String? = "2026:10:01 09:15:00",
                     offset: String? = "-04:00", gps: Bool = true) -> Data {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(UIColor.red.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w / 2, height: h))
        ctx.setFillColor(UIColor.blue.cgColor); ctx.fill(CGRect(x: w / 2, y: 0, width: w - w / 2, height: h))
        ctx.setFillColor(UIColor.green.cgColor); ctx.fill(CGRect(x: 0, y: h - h / 10, width: w, height: h / 10))
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        var exif: [CFString: Any] = [kCGImagePropertyExifLensModel: "Fixture Lens"]
        if let date { exif[kCGImagePropertyExifDateTimeOriginal] = date }
        if let offset { exif[kCGImagePropertyExifOffsetTimeOriginal] = offset }
        var props: [CFString: Any] = [kCGImagePropertyOrientation: orientation, kCGImagePropertyExifDictionary: exif,
                                      kCGImageDestinationLossyCompressionQuality: 0.95]
        if gps {
            props[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude: 43.65, kCGImagePropertyGPSLatitudeRef: "N",
                                                    kCGImagePropertyGPSLongitude: 79.38, kCGImagePropertyGPSLongitudeRef: "W"]
        }
        CGImageDestinationAddImage(dest, ctx.makeImage()!, props as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    static func properties(_ data: Data) -> [CFString: Any] {
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        return CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
    }

    static func pixelSize(_ data: Data) -> (w: Int, h: Int) {
        let p = properties(data)
        return (p[kCGImagePropertyPixelWidth] as! Int, p[kCGImagePropertyPixelHeight] as! Int)
    }

    /// RGB at a relative position of the decoded image (top-left origin).
    static func color(_ data: Data, x: Double, y: Double) -> (r: Int, g: Int, b: Int) {
        let cg = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(data as CFData, nil)!, 0, nil)!
        let px = Int(Double(cg.width - 1) * x), py = Int(Double(cg.height - 1) * y)
        var rgba = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -px, y: -(cg.height - 1 - py), width: cg.width, height: cg.height))
        return (Int(rgba[0]), Int(rgba[1]), Int(rgba[2]))
    }
}

@Suite struct MMEvidenceImportTests {
    private typealias F = EvidenceFixture

    // MARK: Source: exact bytes, real type

    @Test(arguments: [(UTType.jpeg, "image/jpeg", "jpg"), (.heic, "image/heic", "heic"), (.png, "image/png", "png")])
    func sourceIsTheExactFileWithItsRealType(type: UTType, mime: String, ext: String) throws {
        let data = F.make(1500, 1000, type: type)
        let source = try MMEvidenceImport.source(from: data, captureSource: .library)
        #expect(source.data == data)
        #expect(source.mimeType == mime && source.fileExtension == ext)
        #expect(source.pixelWidth == 1500 && source.pixelHeight == 1000)
        #expect(source.sha256Hex == SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        #expect(F.properties(source.data)[kCGImagePropertyGPSDictionary] != nil)  // GPS stays in the source
    }

    @Test(arguments: [UTType.gif, .tiff, .bmp])
    func otherFormatsAreRefusedNotConverted(type: UTType) {
        #expect(throws: MMEvidenceImportError.self) {
            _ = try MMEvidenceImport.source(from: F.make(200, 100, type: type), captureSource: .library)
        }
    }

    @Test func sourcesOver25MBAreRefusedNotShrunk() throws {
        var data = F.make(400, 300)
        data.append(Data(repeating: 0, count: MMEvidenceImport.maxSourceBytes))  // still a valid JPEG, now > 25 MB
        #expect(throws: MMEvidenceImportError.tooLarge(bytes: data.count)) {
            _ = try MMEvidenceImport.source(from: data, captureSource: .camera)
        }
    }

    @Test func captureDateComesFromTheFile() throws {
        let withOffset = try MMEvidenceImport.source(from: F.make(100, 100, offset: "-04:00"), captureSource: .library)
        #expect(withOffset.capturedAt == ISO8601DateFormatter().date(from: "2026-10-01T13:15:00Z"))
        let noDate = try MMEvidenceImport.source(from: F.make(100, 100, date: nil, offset: nil), captureSource: .library)
        #expect(noDate.capturedAt == nil)
    }

    // MARK: Derivative and thumbnail: never upscale, never crop, upright, no GPS

    @Test(arguments: [(700, 700), (1500, 1000), (3000, 2000), (4032, 3024), (5000, 2500), (1170, 2532)])
    func derivativeNeverUpscalesOrCrops(w: Int, h: Int) throws {
        for type in [UTType.jpeg, .heic, .png] {
            let source = try MMEvidenceImport.source(from: F.make(w, h, type: type), captureSource: .library)
            let derivative = try #require(MMEvidenceImport.derivative(from: source))
            let size = F.pixelSize(derivative)
            let expectedLong = min(4096, max(w, h))
            #expect(max(size.w, size.h) == expectedLong, "\(type.identifier) \(w)x\(h) → \(size)")
            #expect(size.w <= w && size.h <= h)
            #expect(abs(Double(size.w) / Double(size.h) - Double(w) / Double(h)) < 0.002)  // aspect kept
            // Colour layout intact: no crop, no rotation.
            #expect(F.color(derivative, x: 0.25, y: 0.5).r > 200 && F.color(derivative, x: 0.75, y: 0.5).b > 200)
            #expect(F.color(derivative, x: 0.5, y: 0.03).g > 200 && F.color(derivative, x: 0.5, y: 0.2).g < 60)

            let p = F.properties(derivative)
            #expect(p[kCGImagePropertyGPSDictionary] == nil)
            #expect((p[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:01 09:15:00")
            #expect((p[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifLensModel] == nil)
            #expect(CGImageSourceGetType(CGImageSourceCreateWithData(derivative as CFData, nil)!) as String? == UTType.jpeg.identifier)

            let thumb = try #require(MMEvidenceImport.thumbnail(from: source))
            let t = F.pixelSize(thumb)
            #expect(max(t.w, t.h) == min(320, max(w, h)) && t.w <= w && t.h <= h)
            // No source metadata in thumbnails (ImageIO's writer adds its own technical EXIF: dimensions, colour space).
            let thumbExif = F.properties(thumb)[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
            #expect(F.properties(thumb)[kCGImagePropertyGPSDictionary] == nil)
            #expect(thumbExif[kCGImagePropertyExifDateTimeOriginal] == nil && thumbExif[kCGImagePropertyExifLensModel] == nil)
        }
    }

    @Test func orientedSourceProducesUprightDerivative() throws {
        // Orientation 6: stored 4032x3024, displayed 3024x4032 (rotated 90° clockwise).
        let source = try MMEvidenceImport.source(from: F.make(4032, 3024, orientation: 6), captureSource: .camera)
        #expect(source.pixelWidth == 4032 && source.pixelHeight == 3024)  // stored dimensions recorded as-is
        let derivative = try #require(MMEvidenceImport.derivative(from: source))
        #expect(F.pixelSize(derivative) == (3024, 4032))
        #expect(F.properties(derivative)[kCGImagePropertyOrientation] as? Int == 1)
        // Rotated 90° clockwise: the stored top (green) band is now on the right, red on top, blue at the bottom.
        #expect(F.color(derivative, x: 0.97, y: 0.5).g > 200)
        #expect(F.color(derivative, x: 0.4, y: 0.2).r > 200 && F.color(derivative, x: 0.4, y: 0.8).b > 200)
    }

    @Test func derivativeShrinksItselfToFitNeverTheSource() throws {
        let data = F.make(3000, 2000)
        let source = try MMEvidenceImport.source(from: data, captureSource: .library)
        let roomy = try #require(MMEvidenceImport.derivative(from: source))
        let tight = try #require(MMEvidenceImport.derivative(from: source, maxBytes: roomy.count / 4))
        #expect(tight.count <= roomy.count / 4)
        #expect(MMEvidenceImport.derivative(from: source, maxBytes: roomy.count / 4) == tight)  // deterministic
        #expect(source.data == data)  // the source is untouched
    }

    @Test func derivedImagesDoNotDependOnDisplayScaleAndAreDeterministic() throws {
        let source = try MMEvidenceImport.source(from: F.make(1500, 1000), captureSource: .library)
        let first = try #require(MMEvidenceImport.derivative(from: source))
        #expect(MMEvidenceImport.derivative(from: source) == first)
        #expect(F.pixelSize(first) == (1500, 1000))  // the old renderer gave 3600x2400 here on 3x screens
        // Cross-device check: digests written per display scale and compared by the harness.
        if let dir = ProcessInfo.processInfo.environment["MM_EVIDENCE_DIGEST_DIR"] {
            var lines: [String] = []
            for (w, h) in [(700, 700), (1500, 1000), (4032, 3024), (5000, 2500)] {
                let s = try MMEvidenceImport.source(from: F.make(w, h), captureSource: .library)
                let d = try #require(MMEvidenceImport.derivative(from: s)), t = try #require(MMEvidenceImport.thumbnail(from: s))
                lines.append("\(w)x\(h) derivative=\(F.pixelSize(d)) \(SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined().prefix(16)) thumbnail=\(F.pixelSize(t))")
            }
            let scale = UITraitCollection.current.displayScale
            try lines.joined(separator: "\n").write(toFile: "\(dir)/digests-\(Int(scale))x.txt", atomically: true, encoding: .utf8)
        }
    }
}
