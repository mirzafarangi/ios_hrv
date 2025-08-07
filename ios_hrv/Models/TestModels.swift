import Foundation

// MARK: - Test Models for Timestamp Precision
// Isolated test models for debugging chronological plotting issues

/// Test data point with full timestamp precision (not just date)
struct TestDataPoint: Codable, Identifiable {
    let id = UUID()
    let timestamp: String  // Full ISO timestamp with 1-second precision
    let rmssd: Double
    
    /// Convert timestamp string to Date object for chart rendering
    var dateValue: Date {
        // Try multiple formatters to handle different timestamp formats
        let formatters = [
            // ISO8601 without fractional seconds (most common from API)
            { () -> ISO8601DateFormatter in
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }(),
            // ISO8601 with fractional seconds (fallback)
            { () -> ISO8601DateFormatter in
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }()
        ]
        
        // Try each formatter until one succeeds
        for formatter in formatters {
            if let date = formatter.date(from: timestamp) {
                return date
            }
        }
        
        // Fallback: try custom DateFormatter for edge cases
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = customFormatter.date(from: timestamp) {
            return date
        }
        
        // Last resort: return current date (should not happen with valid API data)
        print("⚠️ Failed to parse timestamp: \(timestamp)")
        return Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, rmssd
    }
}

/// Test sleep interval analysis response with timestamp precision
struct TestSleepIntervalResponse: Codable {
    let raw: [TestDataPoint]
    let rollingAvg: [TestDataPoint]?
    let baseline: Double?
    let sdBand: SDBand?
    let percentile10: Double?
    let percentile90: Double?
    let message: String?
    
    private enum CodingKeys: String, CodingKey {
        case raw
        case rollingAvg = "rolling_avg"
        case baseline
        case sdBand = "sd_band"
        case percentile10 = "percentile_10"
        case percentile90 = "percentile_90"
        case message
    }
}

/// Test chart configuration for visual layers
struct TestChartLayerConfig {
    let showRawData: Bool
    let showRollingAverage: Bool
    let showBaseline: Bool
    let showSDBand: Bool
    let showPercentiles: Bool
    
    /// Create configuration based on available test data
    static func from(response: TestSleepIntervalResponse) -> TestChartLayerConfig {
        return TestChartLayerConfig(
            showRawData: !response.raw.isEmpty,
            showRollingAverage: response.rollingAvg != nil && !response.rollingAvg!.isEmpty,
            showBaseline: response.baseline != nil,
            showSDBand: response.sdBand != nil,
            showPercentiles: response.percentile10 != nil && response.percentile90 != nil
        )
    }
}

// MARK: - Chart Data Helpers for Test Mode

extension TestSleepIntervalResponse {
    /// Get Y-axis range for chart scaling
    var yAxisRange: ClosedRange<Double> {
        var allValues: [Double] = raw.map { $0.rmssd }
        
        // Include rolling average values
        if let rollingAvg = rollingAvg {
            allValues.append(contentsOf: rollingAvg.map { $0.rmssd })
        }
        
        // Include baseline
        if let baseline = baseline {
            allValues.append(baseline)
        }
        
        // Include SD band bounds
        if let sdBand = sdBand {
            allValues.append(sdBand.upper)
            allValues.append(sdBand.lower)
        }
        
        // Include percentiles
        if let p10 = percentile10 {
            allValues.append(p10)
        }
        if let p90 = percentile90 {
            allValues.append(p90)
        }
        
        guard !allValues.isEmpty else {
            return 0...100  // Default range
        }
        
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 100
        let padding = (maxValue - minValue) * 0.1  // 10% padding
        
        return (minValue - padding)...(maxValue + padding)
    }
    
    /// Get X-axis timestamp range for precise chart scaling
    var timestampRange: ClosedRange<Date> {
        let allDates = raw.map { $0.dateValue }
        guard !allDates.isEmpty else {
            return Date()...Date()
        }
        
        let minDate = allDates.min() ?? Date()
        let maxDate = allDates.max() ?? Date()
        
        // Add small padding for better visualization
        let padding: TimeInterval = 60  // 1 minute padding on each side
        
        return (minDate.addingTimeInterval(-padding))...(maxDate.addingTimeInterval(padding))
    }
    
    /// Check if response has any data to display
    var hasData: Bool {
        return !raw.isEmpty
    }
    
    /// Get statistics summary for display
    var statisticsSummary: String {
        guard !raw.isEmpty else {
            return "No data available"
        }
        
        let rmssdValues = raw.map { $0.rmssd }
        let mean = rmssdValues.reduce(0, +) / Double(rmssdValues.count)
        let min = rmssdValues.min() ?? 0
        let max = rmssdValues.max() ?? 0
        
        var summary = String(format: "Mean: %.1f ms, Range: %.1f - %.1f ms", mean, min, max)
        
        if let baseline = baseline {
            summary += String(format: ", Baseline: %.1f ms", baseline)
        }
        
        return summary
    }
}
