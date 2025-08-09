/**
 * APIClient.swift
 * API client for HRV iOS App
 * Communicates with Python backend via HTTP
 */

import Foundation

class APIClient {
    
    // MARK: - Configuration
    private let baseURL: URL
    private let urlSession: URLSession
    
    // MARK: - Endpoints
    private enum Endpoint {
        case uploadSession
        case sessionStatus(String)
        case rawSessions(String)
        case processedSessions(String)
        case sessionStatistics(String)
        case health
        case healthDetailed
        
        var path: String {
            switch self {
            case .uploadSession:
                return "/api/v1/sessions/upload"
            case .sessionStatus(let sessionId):
                return "/api/v1/sessions/status/\(sessionId)"
            case .rawSessions(let userId):
                return "/api/v1/sessions/processed/\(userId)" // Note: Railway API doesn't have raw endpoint, using processed
            case .processedSessions(let userId):
                return "/api/v1/sessions/processed/\(userId)"
            case .sessionStatistics(let userId):
                return "/api/v1/sessions/statistics/\(userId)"
            case .health:
                return "/health"
            case .healthDetailed:
                return "/health/detailed"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        // Configure base URL (production Railway deployment)
        if let customURL = ProcessInfo.processInfo.environment["HRV_API_URL"] {
            self.baseURL = URL(string: customURL)!
        } else {
            // Default to deployed Railway API
            self.baseURL = URL(string: "https://hrv-brain-api-production.up.railway.app")!
        }
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.urlSession = URLSession(configuration: config)
        
        print("🌐 APIClient initialized with base URL: \(baseURL)")
    }
    
    // MARK: - Authentication Headers
    
    private func addAuthHeaders(to request: inout URLRequest) async {
        // Get Supabase access token
        if let accessToken = await SupabaseAuthService.shared.getCurrentAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            print("Added Supabase auth header to request")
        } else {
            print("No Supabase access token available")
        }
    }
    
    // MARK: - Public Interface
    func uploadSession(_ session: Session) async throws -> [String: Any] {
        let endpoint = Endpoint.uploadSession
        let url = baseURL.appendingPathComponent(endpoint.path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Supabase authentication headers
        await addAuthHeaders(to: &request)
        
        // Create request body
        let payload = session.toAPIPayload()
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("📤 Uploading session: \(session.id)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Upload failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        // Parse and return the full response including validation report
        if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("✅ Session uploaded successfully: \(session.id)")
            
            // Log validation report if present
            if let validationReport = responseDict["validation_report"] as? [String: Any],
               let validationResult = validationReport["validation_result"] as? [String: Any],
               let isValid = validationResult["is_valid"] as? Bool {
                print("📊 Validation result: valid=\(isValid)")
            }
            
            return responseDict
        } else {
            print("✅ Session uploaded successfully: \(session.id) (no response body)")
            return [:]
        }
    }
    
    func getSessionStatus(_ sessionId: String) async throws -> SessionStatusResponse {
        let endpoint = Endpoint.sessionStatus(sessionId)
        let url = baseURL.appendingPathComponent(endpoint.path)
        
        var request = URLRequest(url: url)
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        return try JSONDecoder().decode(SessionStatusResponse.self, from: data)
    }
    
    func getRawSessions(userId: String) async throws -> [RawSession] {
        let endpoint = Endpoint.rawSessions(userId)
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidResponse
        }
        
        print("🔍 Raw Sessions URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        await addAuthHeaders(to: &request)
        
        let (data, networkResponse) = try await urlSession.data(for: request)
        
        guard let httpResponse = networkResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats to handle API inconsistencies
            let formatters: [Any] = [
                // CRITICAL FIX: ISO8601 with fractional seconds and timezone
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),                // Format 1: "2025-08-03T00:03:23Z" (with Z)
                ISO8601DateFormatter(),
                // Format 2: "2025-08-03T00:04:23.488098" (with microseconds, no Z)
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }(),
                // Format 3: "2025-08-03T00:04:23" (basic ISO without Z)
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }()
            ]
            
            for formatter in formatters {
                if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                } else if let dateFormatter = formatter as? DateFormatter {
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from: \(dateString)")
        }
        
        let decodedResponse = try decoder.decode(RawSessionsResponse.self, from: data)
        return decodedResponse.sessions
    }
    
    func getProcessedSessions(userId: String) async throws -> [ProcessedSession] {
        let endpoint = Endpoint.processedSessions(userId)
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidResponse
        }
        
        print("🔍 Processed Sessions URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        await addAuthHeaders(to: &request)
        
        let (data, networkResponse) = try await urlSession.data(for: request)
        
        guard let httpResponse = networkResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats to handle API inconsistencies
            let formatters: [Any] = [
                // CRITICAL FIX: ISO8601 with fractional seconds and timezone
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),                // Format 1: "2025-08-03T00:03:23Z" (with Z)
                ISO8601DateFormatter(),
                // Format 2: "2025-08-03T00:04:23.488098" (with microseconds, no Z)
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }(),
                // Format 3: "2025-08-03T00:04:23" (basic ISO without Z)
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    return formatter
                }()
            ]
            
            for formatter in formatters {
                if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                } else if let dateFormatter = formatter as? DateFormatter {
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from: \(dateString)")
        }
        
        let decodedResponse = try decoder.decode(ProcessedSessionsResponse.self, from: data)
        return decodedResponse.sessions
    }
    
    func getSessionStatistics(userId: String) async throws -> SessionStatistics {
        let endpoint = Endpoint.sessionStatistics(userId)
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidResponse
        }
        
        print("🔍 Statistics URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(SessionStatistics.self, from: data)
    }
    
    func getHealthStatus() async throws -> HealthResponse {
        let endpoint = Endpoint.health
        let url = baseURL.appendingPathComponent(endpoint.path)
        
        var request = URLRequest(url: url)
        await addAuthHeaders(to: &request)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
}

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case serverError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models
struct SessionStatusResponse: Codable {
    let sessionId: String
    let status: String
    let processedAt: Date?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case processedAt = "processed_at"
        case error
    }
}

// RawSessionsResponse model moved to UnifiedModels.swift for clean schema.md compliance

// RawSession model moved to UnifiedModels.swift for clean schema.md compliance

// All models moved to UnifiedModels.swift for clean schema.md compliance

struct HealthResponse: Codable {
    let status: String
    let version: String
    let timestamp: String
    let api: APIStatus
    let firebase: FirebaseStatus
    let performance: PerformanceMetrics
    
    struct APIStatus: Codable {
        let status: String
        let uptime: Double
    }
    
    struct FirebaseStatus: Codable {
        let status: String
        let connectivity: Bool
        let databaseUrl: String
        
        enum CodingKeys: String, CodingKey {
            case status
            case connectivity
            case databaseUrl = "database_url"
        }
    }
    
    struct PerformanceMetrics: Codable {
        let responseTimeMs: Double
        
        enum CodingKeys: String, CodingKey {
            case responseTimeMs = "response_time_ms"
        }
    }
}
