import Foundation

// MARK: - Baseline Response Models
// Models matching the baseline API response structure from blueprint_baseline.md

struct BaselineResponse: Codable {
    let userId: String
    let updatedAt: String
    let mPointsRequested: Int
    let nPointsRequested: Int
    let maxSessions: Int
    let totalSessions: Int
    let metrics: [String]
    let fixedBaseline: [String: BaselineStats]
    let dynamicBaseline: [DynamicBaselineSession]
    let warnings: [String]
    let notes: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case updatedAt = "updated_at"
        case mPointsRequested = "m_points_requested"
        case nPointsRequested = "n_points_requested"
        case maxSessions = "max_sessions"
        case totalSessions = "total_sessions"
        case metrics
        case fixedBaseline = "fixed_baseline"
        case dynamicBaseline = "dynamic_baseline"
        case warnings
        case notes
    }
}

struct BaselineStats: Codable {
    let mean: Double
    let median: Double
    let sd: Double
    let mad: Double
    let meanPlus1SD: Double
    let meanMinus1SD: Double
    let meanPlus2SD: Double
    let meanMinus2SD: Double
    let count: Int
    let sessionIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case mean, median, sd, mad, count
        case meanPlus1SD = "mean_plus_1sd"
        case meanMinus1SD = "mean_minus_1sd"
        case meanPlus2SD = "mean_plus_2sd"
        case meanMinus2SD = "mean_minus_2sd"
        case sessionIds = "session_ids"
    }
}

struct DynamicBaselineSession: Codable {
    let sessionId: String
    let sessionIndex: Int
    let timestamp: String
    let durationMinutes: Int
    let metrics: [String: Double?]
    let rollingStats: [String: RollingStats?]
    let trends: [String: TrendInfo]
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sessionIndex = "session_index"
        case timestamp
        case durationMinutes = "duration_minutes"
        case metrics
        case rollingStats = "rolling_stats"
        case trends
        case tags
    }
}

struct RollingStats: Codable {
    let mean: Double
    let median: Double
    let sd: Double
    let mad: Double
    let meanPlus1SD: Double
    let meanMinus1SD: Double
    let meanPlus2SD: Double
    let meanMinus2SD: Double
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case mean, median, sd, mad, count
        case meanPlus1SD = "mean_plus_1sd"
        case meanMinus1SD = "mean_minus_1sd"
        case meanPlus2SD = "mean_plus_2sd"
        case meanMinus2SD = "mean_minus_2sd"
    }
}

struct TrendInfo: Codable {
    let deltaVsFixed: Double?
    let pctVsFixed: Double?
    let zScoreVsFixed: Double?
    let deltaVsRolling: Double?
    let pctVsRolling: Double?
    let zScoreVsRolling: Double?
    let direction: String
    let significance: String?
    
    enum CodingKeys: String, CodingKey {
        case deltaVsFixed = "delta_vs_fixed"
        case pctVsFixed = "pct_vs_fixed"
        case zScoreVsFixed = "z_score_vs_fixed"
        case deltaVsRolling = "delta_vs_rolling"
        case pctVsRolling = "pct_vs_rolling"
        case zScoreVsRolling = "z_score_vs_rolling"
        case direction
        case significance
    }
}

// MARK: - UI Helper Models

struct MetricKPI {
    let metric: String
    let label: String
    let unit: String
    let value: Double?
    let deltaFixed: Double?
    let pctFixed: Double?
    let deltaRolling: Double?
    let pctRolling: Double?
    let direction: String
    let significance: String?
    
    var formattedValue: String {
        guard let value = value else { return "N/A" }
        switch metric {
        case "mean_hr":
            return String(format: "%.0f", value)
        case "sd2_sd1":
            return String(format: "%.2f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
    
    var formattedDeltaFixed: String {
        guard let delta = deltaFixed, let pct = pctFixed else { return "" }
        let sign = delta >= 0 ? "+" : ""
        let deltaStr: String
        switch metric {
        case "mean_hr":
            deltaStr = String(format: "%@%.0f", sign, delta)
        case "sd2_sd1":
            deltaStr = String(format: "%@%.2f", sign, delta)
        default:
            deltaStr = String(format: "%@%.1f", sign, delta)
        }
        return "\(deltaStr) (\(sign)\(String(format: "%.1f", pct))%)"
    }
    
    var directionSymbol: String {
        switch direction {
        case "above_baseline":
            return "↑"
        case "below_baseline":
            return "↓"
        default:
            return "→"
        }
    }
    
    var directionColor: String {
        switch direction {
        case "above_baseline":
            return "#D55E00"  // Vermillion
        case "below_baseline":
            return "#0072B2"  // Blue
        default:
            return "#7F7F7F"  // Gray
        }
    }
}

// MARK: - Baseline Parameters

struct BaselineParameters {
    var m: Int = 13  // Fixed baseline window
    var n: Int = 7   // Rolling window
    var k: Int = 13  // Viewport sessions (UI only)
    var maxSessions: Int = 100
    
    static let `default` = BaselineParameters()
}
