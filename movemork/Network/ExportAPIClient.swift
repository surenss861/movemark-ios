import Foundation
import OSLog

private let exportAPILog = Logger(subsystem: "movemark.movemork", category: "ExportAPI")

enum ExportFormat: String, Codable {
    case pdf
}

enum ExportType: String, Codable {
    case moveInReport = "move_in_report"
}

enum ExportJobStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
}

struct MoveInExportRequest: Codable {
    let propertyId: String
    let format: ExportFormat
}

struct MoveInExportResponse: Codable {
    let exportId: String
    let status: ExportJobStatus
    let type: ExportType
    let requestedAt: String

    enum CodingKeys: String, CodingKey {
        case exportId
        case status
        case type
        case requestedAt
    }
}

/// Matches movemark-api JSON (`c.json` uses camelCase: userId, propertyId, …).
struct ExportListItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let propertyId: UUID
    let type: String
    let status: ExportJobStatus
    let requestedAt: String?
    let completedAt: String?
    let filePath: String?
    let createdAt: String?
}

struct ExportDownloadResponse: Codable {
    let exportId: String
    let status: ExportJobStatus
    let downloadUrl: String
    let expiresInSeconds: Int
}

enum APIClientError: LocalizedError {
    case invalidBaseURL
    case missingAuthToken
    case invalidResponse
    case serverError(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid API base URL."
        case .missingAuthToken:
            return "Missing auth token."
        case .invalidResponse:
            return "Invalid server response."
        case .serverError(let message):
            return message
        case .decodingFailed:
            return "Failed to decode server response."
        }
    }
}

final class ExportAPIClient {
    private let session: URLSession
    private let baseURL: URL

    init(baseURLString: String, session: URLSession = .shared) throws {
        guard let url = URL(string: baseURLString) else {
            throw APIClientError.invalidBaseURL
        }
        self.baseURL = url
        self.session = session
    }

    func requestMoveInExport(propertyId: UUID, accessToken: String) async throws -> MoveInExportResponse {
        guard !accessToken.isEmpty else {
            throw APIClientError.missingAuthToken
        }

        let endpoint = baseURL.appendingPathComponent("api/exports/move-in")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = MoveInExportRequest(propertyId: propertyId.uuidString, format: .pdf)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIClientError.serverError(message)
        }

        do {
            return try JSONDecoder().decode(MoveInExportResponse.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    func fetchExports(accessToken: String) async throws -> [ExportListItem] {
        guard !accessToken.isEmpty else {
            throw APIClientError.missingAuthToken
        }

        let endpoint = baseURL.appendingPathComponent("api/exports")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(800)) } ?? "<binary>"
        exportAPILog.notice(
            "GET exports url=\(endpoint.absoluteString, privacy: .public) hasToken=\(!accessToken.isEmpty, privacy: .public) status=\(httpResponse.statusCode, privacy: .public)"
        )

        guard 200..<300 ~= httpResponse.statusCode else {
            exportAPILog.error("GET exports failure body=\(bodyPreview, privacy: .public)")
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIClientError.serverError(message)
        }

        do {
            return try JSONDecoder().decode([ExportListItem].self, from: data)
        } catch {
            exportAPILog.error("GET exports decode failed error=\(String(describing: error), privacy: .public) body=\(bodyPreview, privacy: .public)")
            throw APIClientError.decodingFailed
        }
    }

    func fetchDownloadURL(exportId: String, accessToken: String) async throws -> ExportDownloadResponse {
        guard !accessToken.isEmpty else {
            throw APIClientError.missingAuthToken
        }

        let endpoint = baseURL.appendingPathComponent("api/exports/\(exportId)/download")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIClientError.serverError(message)
        }

        do {
            return try JSONDecoder().decode(ExportDownloadResponse.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }
}
