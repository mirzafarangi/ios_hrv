import Foundation

// MARK: - Trend Analysis Data Models
// Implements unified JSON response schema from polish_architecture.md

/// Data point for trend analysis (date + RMSSD value)
struct TrendDataPoint: Codable, Identifiable {
    let id = UUID()
    let date: String  // YYYY-MM-DD format from API
    let rmssd: Double
    
    /// Convert date string to Date object for chart rendering
    var dateValue: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case date, rmssd
    }
}

/// SD band data (upper and lower bounds)
struct SDBand: Codable {
    let upper: Double
    let lower: Double
}

/// Complete trend analysis response matching API unified JSON schema
struct TrendAnalysisResponse: Codable {
    let raw: [TrendDataPoint]
    let rollingAvg: [TrendDataPoint]?
    let baseline: Double?
    let sdBand: SDBand?
    let percentile10: Double?
    let percentile90: Double?
    
    private enum CodingKeys: String, CodingKey {
        case raw
        case rollingAvg = "rolling_avg"
        case baseline
        case sdBand = "sd_band"
        case percentile10 = "percentile_10"
        case percentile90 = "percentile_90"
    }
}

/// Trend type enumeration for the three plot scenarios
enum TrendType: String, CaseIterable {
    case rest = "rest"
    case sleepInterval = "sleep-interval"
    case sleepEvent = "sleep-event"
    
    var displayName: String {
        switch self {
        case .rest:
            return "Rest Trend"
        case .sleepInterval:
            return "Sleep Intervals"
        case .sleepEvent:
            return "Sleep Events"
        }
    }
    
    var description: String {
        switch self {
        case .rest:
            return "Non-sleep session trend"
        case .sleepInterval:
            return "All intervals from latest sleep event"
        case .sleepEvent:
            return "Aggregated sleep event trend"
        }
    }
    
    var apiEndpoint: String {
        return "/api/v1/trends/\(rawValue)"
    }
    
    var iconName: String {
        switch self {
        case .rest:
            return "figure.seated.side"
        case .sleepInterval:
            return "moon.fill"
        case .sleepEvent:
            return "bed.double.fill"
        }
    }
}

/// Chart configuration for visual layers per polish_architecture.md
struct ChartLayerConfig {
    let showRawData: Bool
    let showRollingAverage: Bool
    let showBaseline: Bool
    let showSDBand: Bool
    let showPercentiles: Bool
    
    /// Create configuration based on available data
    static func from(response: TrendAnalysisResponse) -> ChartLayerConfig {
        return ChartLayerConfig(
            showRawData: !response.raw.isEmpty,
            showRollingAverage: response.rollingAvg != nil && !response.rollingAvg!.isEmpty,
            showBaseline: response.baseline != nil,
            showSDBand: response.sdBand != nil,
            showPercentiles: response.percentile10 != nil && response.percentile90 != nil
        )
    }
}

/// Cached trend data for offline viewing
struct CachedTrendData: Codable {
    let trendType: String  // TrendType.rawValue
    let response: TrendAnalysisResponse
    let cachedAt: Date
    let userId: String
    
    /// Check if cache is still valid (within 24 hours)
    var isValid: Bool {
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return cachedAt > dayAgo
    }
}

// MARK: - Chart Data Helpers

extension TrendAnalysisResponse {
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
    
    /// Get X-axis date range for chart scaling
    var dateRange: ClosedRange<Date> {
        let allDates = raw.map { $0.dateValue }
        guard !allDates.isEmpty else {
            return Date()...Date()
        }
        
        let minDate = allDates.min() ?? Date()
        let maxDate = allDates.max() ?? Date()
        
        return minDate...maxDate
    }
    
    /// Check if response has any data to display
    var hasData: Bool {
        return !raw.isEmpty
    }
}
