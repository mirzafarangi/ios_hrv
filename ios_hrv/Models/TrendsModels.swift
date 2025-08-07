import Foundation

// MARK: - Trends API Response Models

/// Complete response from trends API endpoint
struct TrendsResponse: Codable {
    let restTrend: TrendData
    let sleepEvent: TrendData
    let sleepBaseline: TrendData
    let generatedAt: Date
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case restTrend = "rest_trend"
        case sleepEvent = "sleep_event"
        case sleepBaseline = "sleep_baseline"
        case generatedAt = "generated_at"
        case userId = "user_id"
    }
}

/// Individual trend data container
struct TrendData: Codable {
    let data: [DataPoint]
    let count: Int
    let description: String
    let latestEventId: Int?
    
    enum CodingKeys: String, CodingKey {
        case data, count, description
        case latestEventId = "latest_event_id"
    }
}

/// Simplified data point that can handle both session and aggregated data
struct DataPoint: Codable {
    let recordedAt: Date
    let rmssd: Double
    let sdnn: Double
    let meanHr: Double?
    let meanRr: Double?
    let countRr: Int?
    let pnn50: Double?
    let cvRr: Double?
    let defa: Double?
    let sd2Sd1: Double?
    let subtag: String?
    
    // For aggregated data
    let eventId: Int?
    let eventStart: Date?
    let avgRmssd: Double?
    let avgSdnn: Double?
    let intervalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case recordedAt = "recorded_at"
        case rmssd, sdnn
        case meanHr = "mean_hr"
        case meanRr = "mean_rr"
        case countRr = "count_rr"
        case pnn50, cvRr = "cv_rr"
        case defa, sd2Sd1 = "sd2_sd1"
        case subtag
        case eventId = "event_id"
        case eventStart = "event_start"
        case avgRmssd = "avg_rmssd"
        case avgSdnn = "avg_sdnn"
        case intervalCount = "interval_count"
    }
    
    // Use appropriate values based on data type
    var displayRmssd: Double {
        return avgRmssd ?? rmssd
    }
    
    var displaySdnn: Double {
        return avgSdnn ?? sdnn
    }
    
    var displayDate: Date {
        return eventStart ?? recordedAt
    }
}



// MARK: - Trend Type Enum

enum TrendType: String, CaseIterable {
    case rest = "Rest Trend"
    case sleepEvent = "Sleep Event"
    case sleepBaseline = "Sleep Baseline"
    
    var description: String {
        switch self {
        case .rest:
            return "Individual rest sessions"
        case .sleepEvent:
            return "Latest sleep event intervals"
        case .sleepBaseline:
            return "Aggregated sleep events"
        }
    }
    
    var color: String {
        switch self {
        case .rest:
            return "blue"
        case .sleepEvent:
            return "green"
        case .sleepBaseline:
            return "purple"
        }
    }
}

// MARK: - Chart Data Processing

extension TrendData {
    /// Get chart data points for plotting
    var chartDataPoints: [ChartDataPoint] {
        return data.compactMap { point in
            ChartDataPoint(
                date: point.displayDate,
                rmssd: point.displayRmssd,
                sdnn: point.displaySdnn
            )
        }
    }
    
    /// Get statistics summary
    var statistics: TrendStatistics {
        let rmssdValues = data.map { $0.displayRmssd }
        let sdnnValues = data.map { $0.displaySdnn }
        
        return TrendStatistics(
            count: count,
            rmssdMean: rmssdValues.isEmpty ? 0 : rmssdValues.reduce(0, +) / Double(rmssdValues.count),
            rmssdMin: rmssdValues.min() ?? 0,
            rmssdMax: rmssdValues.max() ?? 0,
            sdnnMean: sdnnValues.isEmpty ? 0 : sdnnValues.reduce(0, +) / Double(sdnnValues.count),
            sdnnMin: sdnnValues.min() ?? 0,
            sdnnMax: sdnnValues.max() ?? 0
        )
    }
}

/// Chart data point for plotting
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rmssd: Double
    let sdnn: Double
}

/// Statistics summary for trends
struct TrendStatistics {
    let count: Int
    let rmssdMean: Double
    let rmssdMin: Double
    let rmssdMax: Double
    let sdnnMean: Double
    let sdnnMin: Double
    let sdnnMax: Double
}


