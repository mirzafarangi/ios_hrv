import Foundation

// MARK: - Trend Analysis Data Models
// Implements unified JSON response schema from polish_architecture.md

/// Single data point for trend analysis - Updated to handle both date and timestamp fields
struct TrendDataPoint: Codable, Identifiable {
    let id = UUID()
    let date: String?  // ISO date format (YYYY-MM-DD) - legacy field
    let timestamp: String?  // Full ISO timestamp - new field
    let rmssd: Double
    
    /// Convert date/timestamp string to Date object for chart rendering
    var dateValue: Date {
        // Prefer timestamp over date for better precision
        let dateString = timestamp ?? date ?? ""
        
        // Try multiple formatters to handle different formats
        let formatters: [(DateFormatter) -> Void] = [
            // ISO8601 timestamp format (new API format)
            { formatter in
                let iso8601 = ISO8601DateFormatter()
                iso8601.formatOptions = [.withInternetDateTime]
                if let date = iso8601.date(from: dateString) {
                    formatter.dateFormat = "" // Not used, but required
                    // Return the parsed date by setting a property we can access
                }
            },
            // Legacy date-only format
            { formatter in
                formatter.dateFormat = "yyyy-MM-dd"
            }
        ]
        
        // Try ISO8601 first (for timestamp field)
        if let timestamp = timestamp {
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime]
            if let date = iso8601.date(from: timestamp) {
                return date
            }
            
            // Fallback for timestamp with fractional seconds
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: timestamp) {
                return date
            }
        }
        
        // Try date-only format (for legacy date field)
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = formatter.date(from: date) {
                return parsedDate
            }
        }
        
        // Last resort
        print("⚠️ Failed to parse date/timestamp: date=\(date ?? "nil"), timestamp=\(timestamp ?? "nil")")
        return Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case date, timestamp, rmssd
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
