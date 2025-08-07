import Foundation
import Combine
import SwiftUI

/// Test ViewModel for sleep interval chart with timestamp precision
/// Isolated for debugging chronological plotting issues
@MainActor
class TestChartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var testData: TestSleepIntervalResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var chartConfig: TestChartLayerConfig?
    @Published var debugInfo: String = ""
    
    // MARK: - Dependencies
    
    private let networkManager = TestNetworkManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - User Management
    
    private var currentUserId: String? {
        // Get user ID from authentication service
        // This should be integrated with your existing auth system
        return "7015839c-4659-4b6c-821c-2906e710a2db" // Placeholder for testing
    }
    
    // MARK: - Public Methods
    
    /// Load test sleep interval data with timestamp precision
    func loadTestData() {
        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        debugInfo = "Loading test data..."
        
        networkManager.fetchTestSleepInterval(userId: userId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                            self?.testData = nil
                            self?.chartConfig = nil
                            self?.debugInfo = "Error: \(error.localizedDescription)"
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.testData = response
                        self?.chartConfig = TestChartLayerConfig.from(response: response)
                        self?.errorMessage = nil
                        self?.debugInfo = response.message ?? "Test data loaded successfully"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Debug API response
    func debugAPIResponse() {
        guard let userId = currentUserId else {
            debugInfo = "User not authenticated"
            return
        }
        
        debugInfo = "Fetching raw API response..."
        
        networkManager.debugAPIResponse(userId: userId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self?.debugInfo = "Debug Error: \(error.localizedDescription)"
                        }
                    }
                },
                receiveValue: { [weak self] rawResponse in
                    DispatchQueue.main.async {
                        self?.debugInfo = "Raw API Response:\n\(rawResponse)"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Refresh test data
    func refreshTestData() {
        loadTestData()
    }
    
    // MARK: - Computed Properties
    
    /// Check if chart has data to display
    var hasData: Bool {
        return testData?.hasData ?? false
    }
    
    /// Get data point count for display
    var dataPointCount: Int {
        return testData?.raw.count ?? 0
    }
    
    /// Get chart title
    var chartTitle: String {
        return "Test: Sleep Intervals (Timestamp Precision)"
    }
    
    /// Get chart description
    var chartDescription: String {
        return "All intervals from latest sleep event with 1-second X-axis precision"
    }
    
    // MARK: - Chart Data Helpers
    
    /// Get Y-axis domain for chart
    var yAxisDomain: ClosedRange<Double> {
        return testData?.yAxisRange ?? 0...100
    }
    
    /// Get X-axis timestamp domain for precise chart scaling
    var xAxisDomain: ClosedRange<Date> {
        return testData?.timestampRange ?? Date()...Date()
    }
    
    /// Get statistics summary for display
    var statisticsSummary: String {
        return testData?.statisticsSummary ?? "No data available"
    }
    
    /// Get timestamp range info for debugging
    var timestampRangeInfo: String {
        guard let data = testData, !data.raw.isEmpty else {
            return "No timestamp data"
        }
        
        let firstTimestamp = data.raw.first?.timestamp ?? "Unknown"
        let lastTimestamp = data.raw.last?.timestamp ?? "Unknown"
        let duration = data.raw.last?.dateValue.timeIntervalSince(data.raw.first?.dateValue ?? Date()) ?? 0
        
        return "Range: \(firstTimestamp) to \(lastTimestamp) (Duration: \(Int(duration))s)"
    }
    
    // MARK: - Lifecycle
    
    init() {
        // Load initial test data
        loadTestData()
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension TestChartViewModel {
    /// Create mock test data for preview
    static func mockViewModel() -> TestChartViewModel {
        let viewModel = TestChartViewModel()
        
        // Create mock test data with proper timestamp progression
        let baseDate = Date()
        let mockDataPoints = [
            TestDataPoint(timestamp: baseDate.addingTimeInterval(0).ISO8601Format(), rmssd: 12.14),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(60).ISO8601Format(), rmssd: 5.86),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(120).ISO8601Format(), rmssd: 3.81),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(180).ISO8601Format(), rmssd: 6.23),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(240).ISO8601Format(), rmssd: 5.28)
        ]
        
        let mockRollingAvg = [
            TestDataPoint(timestamp: baseDate.addingTimeInterval(120).ISO8601Format(), rmssd: 7.27),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(180).ISO8601Format(), rmssd: 5.30),
            TestDataPoint(timestamp: baseDate.addingTimeInterval(240).ISO8601Format(), rmssd: 5.11)
        ]
        
        viewModel.testData = TestSleepIntervalResponse(
            raw: mockDataPoints,
            rollingAvg: mockRollingAvg,
            baseline: 6.66,
            sdBand: SDBand(upper: 8.5, lower: 4.8),
            percentile10: 4.0,
            percentile90: 11.0,
            message: "Mock test data with timestamp progression"
        )
        
        viewModel.chartConfig = TestChartLayerConfig.from(response: viewModel.testData!)
        viewModel.debugInfo = "Mock data loaded for preview"
        
        return viewModel
    }
}
#endif
