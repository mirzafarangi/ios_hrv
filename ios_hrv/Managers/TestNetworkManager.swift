import Foundation
import Combine

/// Test network manager for timestamp precision sleep interval analysis
/// Isolated for debugging chronological plotting issues
@MainActor
class TestNetworkManager: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Test API Methods
    
    /// Fetch test sleep interval data with timestamp precision
    /// - Parameter userId: User ID for analysis
    /// - Returns: Publisher with test sleep interval response
    func fetchTestSleepInterval(userId: String) -> AnyPublisher<TestSleepIntervalResponse, Error> {
        
        // Build test API URL
        guard let url = URL(string: "\(baseURL)/api/v1/test/sleep-interval?user_id=\(userId)") else {
            return Fail(error: TestNetworkError.invalidURL)
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
                    throw TestNetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw TestNetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: TestSleepIntervalResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Debug method to check raw API response
    func debugAPIResponse(userId: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/v1/test/sleep-interval?user_id=\(userId)") else {
            return Fail(error: TestNetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TestNetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw TestNetworkError.httpError(httpResponse.statusCode)
                }
                
                return String(data: data, encoding: .utf8) ?? "Unable to decode response"
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Test Error Types

enum TestNetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid test API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode test response"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check test API configuration"
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
