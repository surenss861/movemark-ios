//
//  ReportFileDownloader.swift
//  movemork
//
//  Downloads export PDFs from signed URLs into per-export cache files with readable names for preview/share;
//  reopening a report uses the cached file.
//

import Foundation

enum ReportFileError: LocalizedError {
    case missingFile
    case emptyFile
    case invalidType
    /// The signed download link was refused (401/403): it expired or was revoked.
    case linkExpired

    var errorDescription: String? {
        switch self {
        case .missingFile, .invalidType, .linkExpired:
            return "Couldn't open report. Please try again."
        case .emptyFile:
            return "Report file was empty. Please regenerate it."
        }
    }
}

enum ReportFileDownloader {

    /// "MoveMark Move-in Report – 88 Harbour St – Oct 27 2026.pdf": what the renter sees in Files, Mail and
    /// AirDrop. Safe for every file system; the rental part is dropped when there is nothing readable in it.
    static func reportFileName(exportType: String, rentalName: String?, date: Date?, locale: Locale = .current,
                               timeZone: TimeZone = .current) -> String {
        var parts = [shareSubject(for: exportType)]
        if let rental = rentalName.map({ sanitizedFileNameComponent($0, maxLength: 60) }), !rental.isEmpty {
            parts.append(rental)
        }
        if let date {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMMdyyyy")
            let stamp = sanitizedFileNameComponent(formatter.string(from: date).replacingOccurrences(of: ",", with: ""),
                                                   maxLength: 24)
            if !stamp.isEmpty { parts.append(stamp) }
        }
        return parts.joined(separator: " \u{2013} ") + ".pdf"
    }

    /// One readable piece of a file name: no path separators, reserved or control characters, no leading
    /// dots, single spaces, at most `maxLength` characters (cut on a word where possible).
    static func sanitizedFileNameComponent(_ raw: String, maxLength: Int) -> String {
        let reserved = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters).union(.newlines)
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.map { reserved.contains($0) ? " " : $0 }))
        var collapsed = cleaned.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        while collapsed.hasPrefix(".") { collapsed.removeFirst() }
        collapsed = collapsed.trimmingCharacters(in: .whitespaces)
        guard collapsed.count > maxLength else { return collapsed }
        let cut = String(collapsed.prefix(maxLength))
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) >= maxLength / 2 {
            return String(cut[..<space]).trimmingCharacters(in: .whitespaces)
        }
        return cut.trimmingCharacters(in: .whitespaces)
    }

    static func displayTitle(for exportType: String) -> String {
        switch exportType {
        case "move_in_report":
            return "Move-in report"
        case "move_out_report":
            return "Move-out report"
        case "dispute_packet", "dispute_summary":
            return "Dispute packet"
        default:
            return "Report"
        }
    }

    static func shareSubject(for exportType: String) -> String {
        switch exportType {
        case "move_in_report":
            return "MoveMark Move-in Report"
        case "move_out_report":
            return "MoveMark Move-out Report"
        case "dispute_packet", "dispute_summary":
            return "MoveMark Dispute Packet"
        default:
            return "MoveMark Report"
        }
    }

    static func reportsCacheDirectory() throws -> URL {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw ReportFileError.missingFile
        }
        let directory = caches.appendingPathComponent("MoveMarkReports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Each export keeps its own folder, so two reports never overwrite each other even with the same name.
    private static func exportDirectory(_ exportId: UUID, in root: URL) -> URL {
        root.appendingPathComponent(exportId.uuidString.lowercased(), isDirectory: true)
    }

    /// The report already downloaded for this export, when its file is still a valid PDF. A generated report
    /// never changes (a new report is a new export), so a cached copy is always current.
    static func cachedReport(exportId: UUID, in root: URL? = nil) -> URL? {
        guard let root = try? root ?? reportsCacheDirectory() else { return nil }
        let folder = exportDirectory(exportId, in: root)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }
        for file in files where file.pathExtension.lowercased() == "pdf" {
            if (try? validateReportFile(at: file)) != nil { return file }
            try? FileManager.default.removeItem(at: file)   // a broken copy is fetched again
        }
        return nil
    }

    /// Removes every downloaded report (sign-out and account deletion: reports are personal records).
    static func clearCache(in root: URL? = nil) {
        guard let root = try? root ?? reportsCacheDirectory() else { return }
        try? FileManager.default.removeItem(at: root)
    }

    static func validateReportFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReportFileError.missingFile
        }
        guard url.pathExtension.lowercased() == "pdf" else {
            throw ReportFileError.invalidType
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? Int64 ?? 0
        guard size > 0 else {
            throw ReportFileError.emptyFile
        }
        // A signed-URL error page (XML/HTML) saved under a .pdf name is not a report.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 4), header == pdfMagic else {
            throw ReportFileError.invalidType
        }
    }

    /// "%PDF" — the first four bytes of every PDF.
    private static let pdfMagic = Data("%PDF".utf8)

    /// Signed-URL downloads are small; fail fast instead of the 60s default when the network stalls.
    private static let downloadTimeout: TimeInterval = 30

    /// Fetches the bytes behind a signed URL. A 401/403 means the link expired (``ReportFileError/linkExpired``).
    static func fetchData(from signedURL: URL) async throws -> Data {
        var request = URLRequest(url: signedURL)
        request.timeoutInterval = downloadTimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw [401, 403].contains(http.statusCode) ? ReportFileError.linkExpired : URLError(.badServerResponse)
        }
        return data
    }

    /// The export's PDF as a local file URL, named for people: the cached copy when there is one, otherwise a
    /// download. An expired signed link is replaced once, silently, before giving up.
    static func localReport(
        exportId: UUID,
        fileName: String,
        in root: URL? = nil,
        fetchSignedURL: () async throws -> URL,
        download: (URL) async throws -> Data = { try await ReportFileDownloader.fetchData(from: $0) }
    ) async throws -> URL {
        let root = try root ?? reportsCacheDirectory()
        if let cached = cachedReport(exportId: exportId, in: root) { return cached }

        let data: Data
        do {
            data = try await download(try await fetchSignedURL())
        } catch ReportFileError.linkExpired {
            data = try await download(try await fetchSignedURL())
        }
        guard !data.isEmpty else { throw ReportFileError.emptyFile }
        guard data.prefix(4) == pdfMagic else { throw ReportFileError.invalidType }

        let folder = exportDirectory(exportId, in: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = fileName.lowercased().hasSuffix(".pdf") ? fileName : fileName + ".pdf"
        let destination = folder.appendingPathComponent(name, isDirectory: false)
        try data.write(to: destination, options: .atomic)
        try validateReportFile(at: destination)
        return destination
    }

    static func makeShareItem(for fileURL: URL, exportType: String) throws -> ReportPDFActivityItem {
        try validateReportFile(at: fileURL)
        return ReportPDFActivityItem(
            fileURL: fileURL,
            subject: shareSubject(for: exportType)
        )
    }
}
