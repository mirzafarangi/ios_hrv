import Foundation
import Combine

/// Trends chart view model for proper HRV analysis
/// Responds to user metric and mode selections, calls correct API endpoints
@MainActor
class TrendsChartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var chartData: [TestDataPoint] = []
    @Published var chartConfig: TestChartLayerConfig?
    @Published var debugInfo: String = ""
    @Published var statisticsSummary: String = ""
    @Published var debugRawJSON: String = ""
    @Published var response: TestSleepIntervalResponse?
    // Rolling 3-point statistics for client-side SD bands
    @Published var rollingStats: [RollingStatsPoint] = []
    @Published var rollingMeanSeries: [ChartLinePoint] = []
    
    // MARK: - Dependencies
    
    private let trendsNetworkManager = TrendsNetworkManager()
    private let authService = SupabaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var dataPointCount: Int {
        chartData.count
    }
    
    var hasData: Bool {
        !chartData.isEmpty
    }
    
    // MARK: - Public Methods
    
    /// Load trend data based on user selections
    /// - Parameters:
    ///   - metric: Selected HRV metric
    ///   - mode: Selected analysis mode
    func loadTrendData(metric: HRVMetric, mode: TrendMode) {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        trendsNetworkManager.fetchTrendData(userId: userId, metric: metric, mode: mode)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                            self?.debugInfo = "Error: \(error.localizedDescription)"
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.processResponse(response, metric: metric, mode: mode)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    /// Process API response and update chart data
    /// - Parameters:
    ///   - response: API response
    ///   - metric: Selected metric
    ///   - mode: Selected mode
    private func processResponse(_ response: TestSleepIntervalResponse, metric: HRVMetric, mode: TrendMode) {
        // Use raw data from response directly
        chartData = response.raw
        
        // Update chart configuration
        chartConfig = TestChartLayerConfig.from(response: response)
        
        // Update statistics summary
        statisticsSummary = formatStatisticsSummary(response, metric: metric)
        
        // Update debug info
        debugInfo = formatDebugInfo(response, mode: mode)
        debugRawJSON = makePrettyJSON(response)
        
        // Clear any error
        errorMessage = nil
        
        // Store full response for chart layers (rolling avg, SD band, percentiles, baseline)
        self.response = response

        // Compute 3-point rolling stats for SD bands and rolling mean (client-side)
        computeRollingStats()
    }
    

    
    /// Get unit string for metric
    /// - Parameter metric: HRV metric
    /// - Returns: Unit string
    private func getMetricUnit(for metric: HRVMetric) -> String {
        switch metric {
        case .rmssd, .sdnn:
            return "ms"
        case .sd2sd1:
            return "ratio"
        case .defa:
            return "α1"
        }
    }
    
    /// Format statistics summary
    /// - Parameters:
    ///   - response: API response
    ///   - metric: Selected metric
    /// - Returns: Formatted summary string
    private func formatStatisticsSummary(_ response: TestSleepIntervalResponse, metric: HRVMetric) -> String {
        let unit = getMetricUnit(for: metric)
        let values = response.raw.map { $0.rmssd }
        guard !values.isEmpty else { return "No data" }
        let mean = values.reduce(0, +) / Double(values.count)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let baseline = response.baseline ?? mean
        let count = values.count
        return "Baseline: \(String(format: "%.2f", baseline)) \(unit)  •  Mean: \(String(format: "%.2f", mean)) \(unit)  •  Range: \(String(format: "%.2f", minV))–\(String(format: "%.2f", maxV)) \(unit)  •  Points: \(count)"
    }
    
    /// Format debug information
    /// - Parameters:
    ///   - response: API response
    ///   - mode: Analysis mode
    /// - Returns: Formatted debug string
    private func formatDebugInfo(_ response: TestSleepIntervalResponse, mode: TrendMode) -> String {
        let modeDescription = getTrendModeDescription(mode)
        let dataCount = response.raw.count
        let timeRange = getTimeRangeDescription(response)
        
        return "\(modeDescription): \(dataCount) points\n\nTime Window: \(timeRange)"
    }

    /// Pretty JSON string for Raw API Response
    private func makePrettyJSON(_ response: TestSleepIntervalResponse) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(response)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "<failed to encode raw response: \(error.localizedDescription)>"
        }
    }
    
    /// Get trend mode description
    /// - Parameter mode: Analysis mode
    /// - Returns: Description string
    private func getTrendModeDescription(_ mode: TrendMode) -> String {
        switch mode {
        case .rest:
            return "Rest trend analysis"
        case .sleepInterval:
            return "Sleep interval analysis"
        case .sleepEvent:
            return "Sleep event analysis"
        }
    }
    
    /// Get time range description from response
    /// - Parameter response: API response
    /// - Returns: Time range string
    private func getTimeRangeDescription(_ response: TestSleepIntervalResponse) -> String {
        guard let firstTimestamp = response.raw.first?.timestamp,
              let lastTimestamp = response.raw.last?.timestamp else {
            return "No time range available"
        }
        
        // Convert timestamp strings to Date objects
        let iso8601Formatter = ISO8601DateFormatter()
        guard let firstDate = iso8601Formatter.date(from: firstTimestamp),
              let lastDate = iso8601Formatter.date(from: lastTimestamp) else {
            return "Invalid timestamp format"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        let duration = lastDate.timeIntervalSince(firstDate)
        let durationString = String(format: "%.0fs", duration)
        
        return "\(formatter.string(from: firstDate)) to \(formatter.string(from: lastDate)) (Duration: \(durationString))"
    }

    // MARK: - Chart Domains for Swift Charts
    
    /// Y-axis domain derived from full response (raw, rolling avg, baseline, SD band, percentiles)
    var yAxisDomain: ClosedRange<Double> {
        // Include sd2 band range if available
        var domain = response?.yAxisRange ?? 0...100
        if !rollingStats.isEmpty {
            let lows = rollingStats.map { $0.sd2Low }
            let highs = rollingStats.map { $0.sd2High }
            let all = lows + highs
            if let minV = all.min(), let maxV = all.max() {
                let pad = (maxV - minV) * 0.1
                domain = (min(domain.lowerBound, minV - pad))...(max(domain.upperBound, maxV + pad))
            }
        }
        return domain
    }
    
    /// X-axis timestamp domain with padding for precise rendering
    var xAxisDomain: ClosedRange<Date> {
        return response?.timestampRange ?? Date()...Date()
    }

    // MARK: - Rolling Stats Types & Logic

    struct ChartLinePoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    struct RollingStatsPoint: Identifiable {
        let id = UUID()
        let date: Date
        let mean: Double
        let sd1Low: Double
        let sd1High: Double
        let sd2Low: Double
        let sd2High: Double
    }

    private func computeRollingStats() {
        // Sort raw by timestamp
        let sorted = chartData.sorted { $0.dateValue < $1.dateValue }
        guard !sorted.isEmpty else {
            self.rollingStats = []
            self.rollingMeanSeries = []
            return
        }

        var stats: [RollingStatsPoint] = []
        var meanSeries: [ChartLinePoint] = []

        func mean(_ arr: [Double]) -> Double {
            guard !arr.isEmpty else { return 0 }
            return arr.reduce(0, +) / Double(arr.count)
        }
        func std(_ arr: [Double], _ m: Double) -> Double {
            guard arr.count > 1 else { return 0 }
            let v = arr.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(arr.count)
            return sqrt(v)
        }

        for i in 0..<sorted.count {
            let start = max(i - 1, 0)
            let end = min(i + 1, sorted.count - 1)
            let window = Array(sorted[start...end])
            let values = window.map { $0.rmssd }
            let m = mean(values)
            let s = std(values, m)
            let date = sorted[i].dateValue

            let sd1Low = m - 1.0 * s
            let sd1High = m + 1.0 * s
            let sd2Low = m - 2.0 * s
            let sd2High = m + 2.0 * s

            stats.append(RollingStatsPoint(date: date, mean: m, sd1Low: sd1Low, sd1High: sd1High, sd2Low: sd2Low, sd2High: sd2High))
            meanSeries.append(ChartLinePoint(date: date, value: m))
        }

        self.rollingStats = stats
        self.rollingMeanSeries = meanSeries
    }
}
