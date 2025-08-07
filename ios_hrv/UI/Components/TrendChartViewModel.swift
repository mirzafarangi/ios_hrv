import Foundation
import Combine
import SwiftUI

/// ViewModel for trend chart components
/// Implements observable state management per polish_architecture.md specifications
@MainActor
class TrendChartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var trendData: TrendAnalysisResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTrendType: TrendType = .rest
    @Published var chartConfig: ChartLayerConfig?
    
    // MARK: - Dependencies
    
    private let networkManager = TrendNetworkManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - User Management
    
    private var currentUserId: String? {
        // Get user ID from authentication service
        // This should be integrated with your existing auth system
        return "7015839c-4659-4b6c-821c-2906e710a2db" // Placeholder for testing
    }
    
    // MARK: - Public Methods
    
    /// Load trend data for the selected trend type
    func loadTrendData() {
        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        networkManager.fetchTrendData(for: selectedTrendType, userId: userId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                            self?.trendData = nil
                            self?.chartConfig = nil
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.trendData = response
                        self?.chartConfig = ChartLayerConfig.from(response: response)
                        self?.errorMessage = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Refresh trend data (bypass cache)
    func refreshTrendData() {
        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        networkManager.refreshTrendData(for: selectedTrendType, userId: userId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.trendData = response
                        self?.chartConfig = ChartLayerConfig.from(response: response)
                        self?.errorMessage = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Switch to a different trend type
    func selectTrendType(_ trendType: TrendType) {
        selectedTrendType = trendType
        loadTrendData()
    }
    
    /// Load all trend types for comparison
    func loadAllTrendData() {
        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        networkManager.fetchAllTrendData(for: userId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] allData in
                    DispatchQueue.main.async {
                        // Use the currently selected trend type data
                        if let selectedData = allData[self?.selectedTrendType ?? .rest] {
                            self?.trendData = selectedData
                            self?.chartConfig = ChartLayerConfig.from(response: selectedData)
                            self?.errorMessage = nil
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Clear all cached data
    func clearCache() {
        networkManager.clearCache()
    }
    
    // MARK: - Computed Properties
    
    /// Check if chart has data to display
    var hasData: Bool {
        return trendData?.hasData ?? false
    }
    
    /// Get chart title based on selected trend type
    var chartTitle: String {
        return selectedTrendType.displayName
    }
    
    /// Get chart description
    var chartDescription: String {
        return selectedTrendType.description
    }
    
    /// Get data point count for display
    var dataPointCount: Int {
        return trendData?.raw.count ?? 0
    }
    
    /// Get cache status information
    var cacheStatus: String {
        guard let userId = currentUserId else { return "No user" }
        
        let status = networkManager.getCacheStatus(for: selectedTrendType, userId: userId)
        
        if status.isCached {
            if let cacheAge = status.cacheAge {
                let hours = Int(cacheAge / 3600)
                let minutes = Int((cacheAge.truncatingRemainder(dividingBy: 3600)) / 60)
                
                if hours > 0 {
                    return "Cached \(hours)h \(minutes)m ago"
                } else {
                    return "Cached \(minutes)m ago"
                }
            } else {
                return "Cached"
            }
        } else {
            return "Not cached"
        }
    }
    
    // MARK: - Chart Data Helpers
    
    /// Get Y-axis domain for chart
    var yAxisDomain: ClosedRange<Double> {
        return trendData?.yAxisRange ?? 0...100
    }
    
    /// Get X-axis domain for chart
    var xAxisDomain: ClosedRange<Date> {
        return trendData?.dateRange ?? Date()...Date()
    }
    
    /// Get statistics summary for display
    var statisticsSummary: String {
        guard let data = trendData, !data.raw.isEmpty else {
            return "No data available"
        }
        
        let rmssdValues = data.raw.map { $0.rmssd }
        let mean = rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        let min = rmssdValues.min() ?? 0
        let max = rmssdValues.max() ?? 0
        
        var summary = String(format: "Mean: %.1f ms, Range: %.1f - %.1f ms", mean, min, max)
        
        if let baseline = data.baseline {
            summary += String(format: ", Baseline: %.1f ms", baseline)
        }
        
        return summary
    }
    
    // MARK: - Lifecycle
    
    init() {
        // Load initial data
        loadTrendData()
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Error Handling

extension TrendChartViewModel {
    /// Handle network errors with user-friendly messages
    private func handleError(_ error: Error) {
        if let trendError = error as? TrendNetworkError {
            switch trendError {
            case .networkUnavailable:
                errorMessage = "No internet connection. Showing cached data if available."
            case .httpError(let code):
                if code == 404 {
                    errorMessage = "No trend data found for this user."
                } else if code >= 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = "Request failed. Please check your data."
                }
            default:
                errorMessage = trendError.localizedDescription
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension TrendChartViewModel {
    /// Create mock data for preview/testing
    static func mockViewModel() -> TrendChartViewModel {
        let viewModel = TrendChartViewModel()
        
        // Create mock trend data
        let mockDataPoints = [
            TrendDataPoint(date: "2025-08-05", rmssd: 42.1),
            TrendDataPoint(date: "2025-08-06", rmssd: 44.3),
            TrendDataPoint(date: "2025-08-07", rmssd: 43.8)
        ]
        
        let mockRollingAvg = [
            TrendDataPoint(date: "2025-08-07", rmssd: 43.4)
        ]
        
        viewModel.trendData = TrendAnalysisResponse(
            raw: mockDataPoints,
            rollingAvg: mockRollingAvg,
            baseline: 43.5,
            sdBand: SDBand(upper: 45.0, lower: 42.0),
            percentile10: 40.0,
            percentile90: 47.0
        )
        
        viewModel.chartConfig = ChartLayerConfig.from(response: viewModel.trendData!)
        
        return viewModel
    }
}
#endif
