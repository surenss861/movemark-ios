//
//  ReportFileDownloader.swift
//  movemork
//
//  Downloads export PDFs from signed URLs into branded local files for preview/share.
//

import Foundation

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

    static func downloadPDF(from signedURL: URL, exportType: String) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: signedURL)
        if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        let fileName = brandedFileName(for: exportType)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName, isDirectory: false)

        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        try data.write(to: destination, options: .atomic)
        return destination
    }
}
