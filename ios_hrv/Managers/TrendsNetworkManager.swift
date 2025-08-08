import Foundation
import Combine

/// Trends network manager for proper HRV analysis endpoint routing
/// Calls correct API endpoints based on user metric and mode selections
@MainActor
class TrendsNetworkManager: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Trends API Methods
    
    /// Fetch trend data based on metric and analysis mode
    /// - Parameters:
    ///   - userId: User ID for analysis
    ///   - metric: HRV metric (rmssd, sdnn, sd2_sd1, defa)
    ///   - mode: Analysis mode (rest, sleep_interval, sleep_event)
    /// - Returns: Publisher with trend response (using same format as test endpoint)
    func fetchTrendData(userId: String, metric: HRVMetric, mode: TrendMode) -> AnyPublisher<TestSleepIntervalResponse, Error> {
        
        // Build trend API URL based on mode
        let endpoint = getTrendEndpoint(for: mode)
        guard let url = URL(string: "\(baseURL)\(endpoint)?user_id=\(userId)") else {
            return Fail(error: TrendsNetworkError.invalidURL)
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
                    throw TrendsNetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw TrendsNetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: TestSleepIntervalResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Get the correct API endpoint based on analysis mode
    /// - Parameter mode: Analysis mode selection
    /// - Returns: API endpoint path
    private func getTrendEndpoint(for mode: TrendMode) -> String {
        switch mode {
        case .rest:
            return "/api/v1/trends/rest"
        case .sleepInterval:
            return "/api/v1/trends/sleep-interval"
        case .sleepEvent:
            return "/api/v1/trends/sleep-event"
        }
    }
}

// MARK: - Trends Network Errors

enum TrendsNetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for trends request"
        case .invalidResponse:
            return "Invalid response from trends API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
