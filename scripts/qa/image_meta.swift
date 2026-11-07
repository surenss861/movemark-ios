// MoveMark QA — print image facts with ImageIO (handles HEIC/HEIF/JPEG/PNG):
//   swift scripts/qa/image_meta.swift <file>...
// One line per file: type, pixel size, orientation, EXIF DateTimeOriginal, GPS present, maker/lens present.
import Foundation
import ImageIO

for path in CommandLine.arguments.dropFirst() {
    guard let data = FileManager.default.contents(atPath: path),
          let src = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
        print("\(path)\tunreadable"); continue
    }
    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
    let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    let fields: [String] = [
        "type=\(CGImageSourceGetType(src) as String? ?? "?")",
        "size=\(props[kCGImagePropertyPixelWidth] ?? "?")x\(props[kCGImagePropertyPixelHeight] ?? "?")",
        "orientation=\(props[kCGImagePropertyOrientation] ?? "none")",
        "captured=\(exif[kCGImagePropertyExifDateTimeOriginal] ?? "none")\(exif[kCGImagePropertyExifOffsetTimeOriginal].map { " \($0)" } ?? "")",
        "gps=\(gps.map { "yes(lat=\($0[kCGImagePropertyGPSLatitude] ?? "?"))" } ?? "none")",
        "camera=\(tiff[kCGImagePropertyTIFFModel] ?? "none")",
        "lens=\(exif[kCGImagePropertyExifLensModel] ?? "none")",
    ]
    print("\(path)\t" + fields.joined(separator: " "))
}
