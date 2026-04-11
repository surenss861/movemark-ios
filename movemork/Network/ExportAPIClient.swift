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

/// Matches movemark-api export list JSON (camelCase or snake_case via shared decoder).
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
    /// Server returned 409 — export row exists but file is not ready yet.
    case exportNotReady

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
        case .exportNotReady:
            return "Export is still processing."
        }
    }
}

final class ExportAPIClient {
    private let session: URLSession
    private let baseURL: URL

    /// Single decoder for all export API responses; tolerates snake_case payloads from the server.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

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
            return try Self.decoder.decode(MoveInExportResponse.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    func fetchExports(accessToken: String, propertyId: UUID) async throws -> [ExportListItem] {
        guard !accessToken.isEmpty else {
            throw APIClientError.missingAuthToken
        }

        var url = baseURL.appendingPathComponent("api/exports")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "propertyId", value: propertyId.uuidString)]
        guard let resolved = components?.url else {
            throw APIClientError.invalidBaseURL
        }
        url = resolved
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(800)) } ?? "<binary>"
        exportAPILog.notice(
            "GET exports url=\(url.absoluteString, privacy: .public) hasToken=\(!accessToken.isEmpty, privacy: .public) status=\(httpResponse.statusCode, privacy: .public)"
        )

        guard 200..<300 ~= httpResponse.statusCode else {
            exportAPILog.error("GET exports failure body=\(bodyPreview, privacy: .public)")
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIClientError.serverError(message)
        }

        do {
            return try Self.decoder.decode([ExportListItem].self, from: data)
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
        if httpResponse.statusCode == 409 {
            throw APIClientError.exportNotReady
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIClientError.serverError(message)
        }

        do {
            return try Self.decoder.decode(ExportDownloadResponse.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    // MARK: - Vault / capabilities / dispute catalog (movemark-api)

    func fetchVaultSummary(
        propertyId: UUID,
        accessToken: String,
        includeExports: Bool = true,
        includeDispute: Bool = true
    ) async throws -> VaultSummaryResponse {
        try await getJSON(
            path: "api/vaults/\(propertyId.uuidString)/summary",
            accessToken: accessToken,
            queryItems: [
                URLQueryItem(name: "includeExports", value: includeExports ? "true" : "false"),
                URLQueryItem(name: "includeDispute", value: includeDispute ? "true" : "false"),
            ],
            as: VaultSummaryResponse.self
        )
    }

    func fetchPropertyCapabilities(
        propertyId: UUID,
        accessToken: String
    ) async throws -> PropertyCapabilitiesResponse {
        try await getJSON(
            path: "api/properties/\(propertyId.uuidString)/capabilities",
            accessToken: accessToken,
            queryItems: [],
            as: PropertyCapabilitiesResponse.self
        )
    }

    func fetchDisputeEvidenceCatalog(
        propertyId: UUID,
        accessToken: String,
        includeSignedUrls: Bool = false
    ) async throws -> DisputeEvidenceCatalogResponse {
        try await getJSON(
            path: "api/disputes/\(propertyId.uuidString)/evidence-catalog",
            accessToken: accessToken,
            queryItems: [
                URLQueryItem(name: "includeSignedUrls", value: includeSignedUrls ? "true" : "false"),
            ],
            as: DisputeEvidenceCatalogResponse.self
        )
    }

    private func getJSON<T: Decodable>(
        path: String,
        accessToken: String,
        queryItems: [URLQueryItem],
        as type: T.Type
    ) async throws -> T {
        guard !accessToken.isEmpty else {
            throw APIClientError.missingAuthToken
        }

        var base = baseURL
        for component in path.split(separator: "/") where !component.isEmpty {
            base = base.appendingPathComponent(String(component))
        }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
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
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            exportAPILog.error(
                "decode failed path=\(path, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            throw APIClientError.decodingFailed
        }
    }
}

/// Same HTTP client as ``ExportAPIClient``; use for all MoveMark Railway API calls.
typealias MoveMarkAPIClient = ExportAPIClient
