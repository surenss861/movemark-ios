//
//  ReportFileDownloaderTests.swift
//  movemorkTests
//
//  Report files: readable, safe names; one cached file per export id (reopening never downloads again);
//  an expired signed link is refreshed once; rental form inline validation.
//

import Foundation
import Testing
@testable import MoveMark

@MainActor
struct ReportFileDownloaderTests {

    private static let pdf = Data("%PDF-1.7\n%test\n".utf8)
    private static let usEnglish = Locale(identifier: "en_US")
    private static let utc = TimeZone(identifier: "UTC")!
    /// Oct 27 2026, 15:00 UTC.
    private static let day = Date(timeIntervalSince1970: 1_793_113_200)

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mm-report-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Names

    @Test func moveInReportNameReadsLikeADocument() {
        let name = ReportFileDownloader.reportFileName(exportType: "move_in_report", rentalName: "88 Harbour St",
                                                       date: Self.day, locale: Self.usEnglish, timeZone: Self.utc)
        #expect(name == "MoveMark Move-in Report \u{2013} 88 Harbour St \u{2013} Oct 27 2026.pdf")
    }

    @Test func otherReportTypesKeepTheirTitles() {
        let out = ReportFileDownloader.reportFileName(exportType: "move_out_report", rentalName: "Unit 4", date: nil)
        #expect(out == "MoveMark Move-out Report \u{2013} Unit 4.pdf")
        let packet = ReportFileDownloader.reportFileName(exportType: "dispute_summary", rentalName: nil, date: nil)
        #expect(packet == "MoveMark Dispute Packet.pdf")
    }

    @Test func rentalNameIsSanitizedForFileSystems() {
        let name = ReportFileDownloader.reportFileName(exportType: "move_in_report",
                                                       rentalName: "../12/B: \"Loft\" <east>\n\t*?|",
                                                       date: nil)
        #expect(name == "MoveMark Move-in Report \u{2013} 12 B Loft east.pdf")
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }

    @Test func emptyOrUnreadableRentalNameIsDropped() {
        let name = ReportFileDownloader.reportFileName(exportType: "move_in_report", rentalName: " /// ", date: nil)
        #expect(name == "MoveMark Move-in Report.pdf")
    }

    @Test func longRentalNameIsCutOnAWord() {
        let long = "1234 Westmoreland Avenue Northwest Apartment Fourteen B Building C Courtyard Entrance"
        let part = ReportFileDownloader.sanitizedFileNameComponent(long, maxLength: 60)
        #expect(part.count <= 60)
        #expect(long.hasPrefix(part))
        #expect(!part.hasSuffix(" "))
        #expect(long.dropFirst(part.count).first == " ")
    }

    // MARK: Cache by export id

    @Test func downloadedReportIsAPDFFileURLInItsExportFolder() async throws {
        let root = try tempRoot()
        let id = UUID()
        let url = try await ReportFileDownloader.localReport(
            exportId: id, fileName: "MoveMark Move-in Report \u{2013} 88 Harbour St.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/signed")! },
            download: { _ in Self.pdf }
        )
        #expect(url.isFileURL)
        #expect(url.pathExtension == "pdf")
        #expect(url.lastPathComponent == "MoveMark Move-in Report \u{2013} 88 Harbour St.pdf")
        #expect(url.deletingLastPathComponent().lastPathComponent == id.uuidString.lowercased())
        #expect(ReportFileDownloader.cachedReport(exportId: id, in: root) == url)
    }

    @Test func reopeningUsesTheCachedFileWithoutFetching() async throws {
        let root = try tempRoot()
        let id = UUID()
        var fetches = 0
        var downloads = 0
        for _ in 0..<3 {
            _ = try await ReportFileDownloader.localReport(
                exportId: id, fileName: "Report.pdf", in: root,
                fetchSignedURL: { fetches += 1; return URL(string: "https://example.com/signed")! },
                download: { _ in downloads += 1; return Self.pdf }
            )
        }
        #expect(fetches == 1)
        #expect(downloads == 1)
    }

    @Test func reportsWithTheSameNameDoNotOverwriteEachOther() async throws {
        let root = try tempRoot()
        let first = try await ReportFileDownloader.localReport(
            exportId: UUID(), fileName: "Same.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/a")! }, download: { _ in Self.pdf + Data("a".utf8) })
        let second = try await ReportFileDownloader.localReport(
            exportId: UUID(), fileName: "Same.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/b")! }, download: { _ in Self.pdf + Data("b".utf8) })
        #expect(first != second)
        #expect(try Data(contentsOf: first).last == UInt8(ascii: "a"))
        #expect(try Data(contentsOf: second).last == UInt8(ascii: "b"))
    }

    @Test func brokenCachedCopyIsFetchedAgain() async throws {
        let root = try tempRoot()
        let id = UUID()
        let url = try await ReportFileDownloader.localReport(
            exportId: id, fileName: "R.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/s")! }, download: { _ in Self.pdf })
        try Data("<Error>AccessDenied</Error>".utf8).write(to: url)
        #expect(ReportFileDownloader.cachedReport(exportId: id, in: root) == nil)
        var downloads = 0
        _ = try await ReportFileDownloader.localReport(
            exportId: id, fileName: "R.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/s")! }, download: { _ in downloads += 1; return Self.pdf })
        #expect(downloads == 1)
    }

    @Test func clearCacheRemovesReports() async throws {
        let root = try tempRoot()
        let id = UUID()
        _ = try await ReportFileDownloader.localReport(
            exportId: id, fileName: "R.pdf", in: root,
            fetchSignedURL: { URL(string: "https://example.com/s")! }, download: { _ in Self.pdf })
        ReportFileDownloader.clearCache(in: root)
        #expect(ReportFileDownloader.cachedReport(exportId: id, in: root) == nil)
    }

    // MARK: Expired links

    @Test func expiredLinkIsRefreshedOnceSilently() async throws {
        let root = try tempRoot()
        var fetches = 0
        var downloads = 0
        let url = try await ReportFileDownloader.localReport(
            exportId: UUID(), fileName: "R.pdf", in: root,
            fetchSignedURL: { fetches += 1; return URL(string: "https://example.com/\(fetches)")! },
            download: { link in
                downloads += 1
                if link.lastPathComponent == "1" { throw ReportFileError.linkExpired }
                return Self.pdf
            }
        )
        #expect(fetches == 2)
        #expect(downloads == 2)
        #expect(url.pathExtension == "pdf")
    }

    @Test func expiredTwiceGivesUp() async throws {
        let root = try tempRoot()
        var fetches = 0
        await #expect(throws: ReportFileError.self) {
            _ = try await ReportFileDownloader.localReport(
                exportId: UUID(), fileName: "R.pdf", in: root,
                fetchSignedURL: { fetches += 1; return URL(string: "https://example.com/s")! },
                download: { _ in throw ReportFileError.linkExpired }
            )
        }
        #expect(fetches == 2)
    }

    @Test func errorPageIsNotSavedAsAReport() async throws {
        let root = try tempRoot()
        let id = UUID()
        await #expect(throws: ReportFileError.self) {
            _ = try await ReportFileDownloader.localReport(
                exportId: id, fileName: "R.pdf", in: root,
                fetchSignedURL: { URL(string: "https://example.com/s")! },
                download: { _ in Data("<html>nope</html>".utf8) }
            )
        }
        #expect(ReportFileDownloader.cachedReport(exportId: id, in: root) == nil)
    }

    // MARK: Rental form inline validation

    @Test func rentalFormFlagsOnlyValuesThatWouldNotSave() {
        #expect(RentalFormFields.emailIssue("") == nil)
        #expect(RentalFormFields.emailIssue("landlord@example.com") == nil)
        #expect(RentalFormFields.emailIssue("landlord@example") != nil)
        #expect(RentalFormFields.emailIssue("landlord example.com") != nil)
        #expect(RentalFormFields.amountIssue("") == nil)
        #expect(RentalFormFields.amountIssue("1500") == nil)
        #expect(RentalFormFields.amountIssue("$1,500.50") == nil)
        #expect(RentalFormFields.amountIssue("1500,50") == nil)
        #expect(RentalFormFields.amountIssue("1.2.3") != nil)
        #expect(RentalFormFields.amountIssue("-5") != nil)
        #expect(RentalFormFields.detailsIssue(email: "", deposit: "abc", rent: "") == "Enter an amount, like 1500.")
    }
}
