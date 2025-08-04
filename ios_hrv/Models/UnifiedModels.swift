/**
 * UnifiedModels.swift
 * Unified data models for HRV iOS App
 * Ensures strict compliance with schema.md and clean Supabase integration
 */

import Foundation

// MARK: - Session Model (Schema.md Compliant)
struct Session: Codable, Identifiable {
    let id: String                // session_id (UUID)
    let userId: String           // user_id (Supabase user.id)
    let tag: String              // Base tag: "rest", "sleep", etc.
    let subtag: String           // Semantic subtag: "rest_single", "sleep_interval_1", etc. (auto-assigned)
    let eventId: Int             // Event grouping ID: 0 = no grouping, >0 = grouped
    let duration: Int            // duration_minutes
    let recordedAt: Date         // recorded_at (ISO8601)
    let rrIntervals: [Double]    // rr_intervals (milliseconds)
    
    // MARK: - Schema.md Compliant Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        tag: String,
        subtag: String,
        eventId: Int,
        duration: Int,
        rrIntervals: [Double],
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.tag = tag
        self.subtag = subtag
        self.eventId = eventId
        self.duration = duration
        self.rrIntervals = rrIntervals
        self.recordedAt = recordedAt
    }
    
    // MARK: - Schema.md Compliant API Payload
    func toAPIPayload() -> [String: Any] {
        return [
            "session_id": id,
            "user_id": userId,
            "tag": tag,
            "subtag": subtag,
            "event_id": eventId,
            "duration_minutes": duration,
            "recorded_at": ISO8601DateFormatter().string(from: recordedAt),
            "rr_intervals": rrIntervals
        ]
    }
    
    // MARK: - Session Logic
    var isSleepInterval: Bool {
        return tag == "sleep" && subtag.starts(with: "sleep_interval_")
    }
    
    var isGroupedSession: Bool {
        return eventId > 0
    }
}

// MARK: - HRV Metrics Model (Schema.md Compliant - All 9 Metrics)
struct HRVMetrics: Codable {
    let meanHr: Double?      // mean_hr (optional for API null handling)
    let meanRr: Double?      // mean_rr (optional for API null handling)
    let countRr: Int?        // count_rr (optional for API null handling)
    let rmssd: Double?       // rmssd (optional for API null handling)
    let sdnn: Double?        // sdnn (optional for API null handling)
    let pnn50: Double?       // pnn50 (optional for API null handling)
    let cvRr: Double?        // cv_rr (optional for API null handling)
    let defa: Double?        // defa (optional for API null handling)
    let sd2Sd1: Double?      // sd2_sd1 (optional for API null handling)
    
    enum CodingKeys: String, CodingKey {
        case meanHr = "mean_hr"
        case meanRr = "mean_rr"
        case countRr = "count_rr"
        case rmssd = "rmssd"
        case sdnn = "sdnn"
        case pnn50 = "pnn50"
        case cvRr = "cv_rr"
        case defa = "defa"
        case sd2Sd1 = "sd2_sd1"
    }
    
    // MARK: - Display Properties
    var allMetrics: [(String, String)] {
        return [
            ("Mean HR", meanHr.map { String(format: "%.1f bpm", $0) } ?? "N/A"),
            ("Mean RR", meanRr.map { String(format: "%.1f ms", $0) } ?? "N/A"),
            ("RR Count", countRr.map { "\($0)" } ?? "N/A"),
            ("RMSSD", rmssd.map { String(format: "%.2f ms", $0) } ?? "N/A"),
            ("SDNN", sdnn.map { String(format: "%.2f ms", $0) } ?? "N/A"),
            ("pNN50", pnn50.map { String(format: "%.1f%%", $0) } ?? "N/A"),
            ("CV RR", cvRr.map { String(format: "%.2f", $0) } ?? "N/A"),
            ("DFA α1", defa.map { String(format: "%.3f", $0) } ?? "N/A"),
            ("SD2/SD1", sd2Sd1.map { String(format: "%.2f", $0) } ?? "N/A")
        ]
    }
}

// MARK: - Processed Session Model (Schema.md Compliant)
struct ProcessedSession: Codable, Identifiable {
    let sessionId: String
    let tag: String
    let subtag: String           // Non-optional to match schema.md
    let eventId: Int             // Event grouping ID from API response
    let status: String
    let durationMinutes: Int
    let recordedAt: Date
    let processedAt: Date
    let hrvMetrics: HRVMetrics
    
    // Computed property for Identifiable protocol
    var id: String { sessionId }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case tag
        case subtag
        case eventId = "event_id"
        case status
        case durationMinutes = "duration_minutes"
        case recordedAt = "recorded_at"
        case processedAt = "processed_at"
        case hrvMetrics = "hrv_metrics"
    }
}

// MARK: - Raw Session Model (Schema.md Compliant)
struct RawSession: Codable, Identifiable {
    let sessionId: String
    let userId: String
    let tag: String
    let subtag: String           // Semantic subtag: auto-assigned per schema.md
    let durationMinutes: Int
    let recordedAt: Date
    let rrIntervals: [Double]
    let rrCount: Int
    let sleepEventId: String?    // String? to match API response
    
    // Computed property for Identifiable protocol
    var id: String { sessionId }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case tag
        case subtag
        case durationMinutes = "duration_minutes"
        case recordedAt = "recorded_at"
        case rrIntervals = "rr_intervals"
        case rrCount = "rr_count"
        case sleepEventId = "sleep_event_id"
    }
}

// MARK: - Session Statistics Model (Schema.md Compliant)
struct SessionStatistics: Codable {
    let rawTotal: Int
    let rawByTag: [String: Int]
    let processedTotal: Int
    let processedByTag: [String: Int]
    let sleepEvents: Int
    
    enum CodingKeys: String, CodingKey {
        case rawTotal = "raw_total"
        case rawByTag = "raw_by_tag"
        case processedTotal = "processed_total"
        case processedByTag = "processed_by_tag"
        case sleepEvents = "sleep_events"
    }
}

// MARK: - API Response Models
struct ProcessedSessionsResponse: Codable {
    let sessions: [ProcessedSession]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
    }
}

struct RawSessionsResponse: Codable {
    let sessions: [RawSession]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
    }
}
