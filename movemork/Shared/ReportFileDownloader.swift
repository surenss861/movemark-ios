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
    }

    static func downloadPDF(from signedURL: URL, exportType: String) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: signedURL)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else {
            throw ReportFileError.emptyFile
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
