import Foundation
import Combine

/// Network manager for trend analysis API endpoints
/// Implements polish_architecture.md specifications for API integration
@MainActor
class TrendNetworkManager: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Management
    
    private let cacheKey = "TrendDataCache"
    
    /// Save trend data to local cache
    private func cacheTrendData(_ data: TrendAnalysisResponse, for trendType: TrendType, userId: String) {
        let cachedData = CachedTrendData(
            trendType: trendType.rawValue,
            response: data,
            cachedAt: Date(),
            userId: userId
        )
        
        if let encoded = try? JSONEncoder().encode(cachedData) {
            let key = "\(cacheKey)_\(trendType.rawValue)_\(userId)"
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    /// Load trend data from local cache
    private func loadCachedTrendData(for trendType: TrendType, userId: String) -> TrendAnalysisResponse? {
        let key = "\(cacheKey)_\(trendType.rawValue)_\(userId)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedData = try? JSONDecoder().decode(CachedTrendData.self, from: data),
              cachedData.isValid else {
            return nil
        }
        
        return cachedData.response
    }
    
    // MARK: - API Methods
    
    /// Fetch trend analysis data from API
    /// - Parameters:
    ///   - trendType: Type of trend analysis (rest, sleep-interval, sleep-event)
    ///   - userId: User ID for trend analysis
    ///   - useCache: Whether to use cached data if available
    /// - Returns: Publisher with trend analysis response
    func fetchTrendData(
        for trendType: TrendType,
        userId: String,
        useCache: Bool = true
    ) -> AnyPublisher<TrendAnalysisResponse, Error> {
        
        // Try cache first if enabled
        if useCache, let cachedData = loadCachedTrendData(for: trendType, userId: userId) {
            return Just(cachedData)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Build API URL
        guard let url = URL(string: "\(baseURL)\(trendType.apiEndpoint)?user_id=\(userId)") else {
            return Fail(error: TrendNetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        // Perform request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TrendNetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw TrendNetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: TrendAnalysisResponse.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { [weak self] response in
                // Cache successful response
                self?.cacheTrendData(response, for: trendType, userId: userId)
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Fetch all three trend types for a user
    /// - Parameter userId: User ID for trend analysis
    /// - Returns: Publisher with dictionary of all trend responses
    func fetchAllTrendData(for userId: String) -> AnyPublisher<[TrendType: TrendAnalysisResponse], Error> {
        let publishers = TrendType.allCases.map { trendType in
            fetchTrendData(for: trendType, userId: userId)
                .map { response in (trendType, response) }
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { results in
                Dictionary(uniqueKeysWithValues: results)
            }
            .eraseToAnyPublisher()
    }
    
    /// Refresh trend data (bypass cache)
    /// - Parameters:
    ///   - trendType: Type of trend analysis
    ///   - userId: User ID for trend analysis
    /// - Returns: Publisher with fresh trend analysis response
    func refreshTrendData(for trendType: TrendType, userId: String) -> AnyPublisher<TrendAnalysisResponse, Error> {
        return fetchTrendData(for: trendType, userId: userId, useCache: false)
    }
    
    /// Clear all cached trend data
    func clearCache() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.hasPrefix(cacheKey) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// Clear cached data for specific user
    func clearCache(for userId: String) {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.hasPrefix(cacheKey) && key.hasSuffix(userId) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Error Types

enum TrendNetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check API configuration"
        case .invalidResponse:
            return "Try again later"
        case .httpError(let code):
            if code >= 500 {
                return "Server error - try again later"
            } else {
                return "Check request parameters"
            }
        case .decodingError:
            return "Data format error - contact support"
        case .networkUnavailable:
            return "Check internet connection"
        }
    }
}

// MARK: - Network Status

extension TrendNetworkManager {
    /// Check if network is available
    var isNetworkAvailable: Bool {
        // Simple network check - could be enhanced with Reachability
        return true
    }
    
    /// Get cache status for a specific trend type and user
    func getCacheStatus(for trendType: TrendType, userId: String) -> (isCached: Bool, cacheAge: TimeInterval?) {
        let key = "\(cacheKey)_\(trendType.rawValue)_\(userId)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedData = try? JSONDecoder().decode(CachedTrendData.self, from: data) else {
            return (false, nil)
        }
        
        let cacheAge = Date().timeIntervalSince(cachedData.cachedAt)
        return (true, cacheAge)
    }
}
