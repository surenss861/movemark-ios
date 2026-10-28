//
//  ReportFileDownloader.swift
//  movemork
//
//  Downloads export PDFs from signed URLs into branded cache files for preview/share.
//

import Foundation

enum ReportFileError: LocalizedError {
    case missingFile
    case emptyFile
    case invalidType

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Couldn't open report. Please try again."
        case .emptyFile:
            return "Report file was empty. Please regenerate it."
        case .invalidType:
            return "Couldn't open report. Please try again."
        }
    }
}

enum ReportFileDownloader {

    static func brandedFileName(for exportType: String) -> String {
        switch exportType {
        case "move_in_report":
            return "MoveMark_Move-In_Report.pdf"
        case "move_out_report":
            return "MoveMark_Move-Out_Report.pdf"
        case "dispute_packet", "dispute_summary":
            return "MoveMark_Dispute_Packet.pdf"
        default:
            return "MoveMark_Report.pdf"
        }
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

    static func downloadPDF(from signedURL: URL, exportType: String) async throws -> URL {
        var request = URLRequest(url: signedURL)
        request.timeoutInterval = downloadTimeout
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else {
            throw ReportFileError.emptyFile
        }
        guard data.prefix(4) == pdfMagic else {
            throw ReportFileError.invalidType
        }

        let directory = try reportsCacheDirectory()
        let destination = directory.appendingPathComponent(brandedFileName(for: exportType), isDirectory: false)

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

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
