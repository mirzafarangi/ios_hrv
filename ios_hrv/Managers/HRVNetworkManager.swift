import Foundation
import Combine

/// Clean network manager for core HRV API operations
/// All chart/trends functionality has been removed for clean regression
/// Handles only essential session upload and basic API operations
@MainActor
class HRVNetworkManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HRVNetworkManager()
    
    // MARK: - Properties
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published States
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Upload session data to API
    func uploadSession(_ sessionData: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/upload") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: sessionData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.noData
        }
        
        return result
    }
    
    /// Basic health check
    func healthCheck() async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.noData
        }
        
        return result
    }
}

// MARK: - Network Error Types

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .noData:
            return "No data received"
        }
    }
}
