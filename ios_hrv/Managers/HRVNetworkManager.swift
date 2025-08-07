import Foundation
import Combine

/// Centralized network manager for all HRV API operations
/// Handles authentication, request management, caching, and error handling
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
    @Published var lastFetchTime: Date?
    
    // MARK: - Cache Management
    private let cacheKey = "HRVTrendsCache"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Rate Limiting
    private let minimumFetchInterval: TimeInterval = 60 // 1 minute
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch trends data with caching and rate limiting
    func fetchTrends(for userId: String, forceRefresh: Bool = false) async throws -> TrendsResponse {
        
        // Check rate limiting
        if !forceRefresh && !canFetch() {
            let remainingTime = getRemainingCooldownTime()
            throw NetworkError.rateLimited(remainingSeconds: Int(remainingTime))
        }
        
        // Try cache first if not forcing refresh
        if !forceRefresh, let cachedData = getCachedTrends() {
            return cachedData
        }
        
        // Set loading state
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let trends = try await performTrendsFetch(userId: userId)
            
            // Cache the result
            cacheTrends(trends)
            lastFetchTime = Date()
            
            return trends
            
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Check if fetch is allowed (rate limiting)
    func canFetch() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) >= minimumFetchInterval
    }
    
    /// Get remaining cooldown time in seconds
    func getRemainingCooldownTime() -> TimeInterval {
        guard let lastFetch = lastFetchTime else { return 0 }
        let elapsed = Date().timeIntervalSince(lastFetch)
        return max(0, minimumFetchInterval - elapsed)
    }
    
    // MARK: - Private Implementation
    
    private func performTrendsFetch(userId: String) async throws -> TrendsResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/trends/refresh") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["user_id": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(TrendsResponse.self, from: data)
    }
    
    // MARK: - Cache Management
    
    private func cacheTrends(_ trends: TrendsResponse) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trends)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            print("Failed to cache trends: \(error)")
        }
    }
    
    private func getCachedTrends() -> TrendsResponse? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TrendsResponse.self, from: data)
        } catch {
            print("Failed to decode cached trends: \(error)")
            return nil
        }
    }
    
    /// Clear cached trends data
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
    }
}

// MARK: - Network Error Types

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case rateLimited(remainingSeconds: Int)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error (Status: \(statusCode))"
        case .rateLimited(let remainingSeconds):
            return "Please wait \(remainingSeconds) seconds before fetching again"
        case .noData:
            return "No data received"
        }
    }
}
