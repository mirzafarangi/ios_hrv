/**
 * UnifiedModels.swift
 * Unified data models for HRV iOS App
 * Ensures strict compliance with schema.md and clean Supabase integration
 */

import Foundation

// MARK: - Session Model (db_schema.sql Compliant)
struct Session: Codable, Identifiable {
    let id: String                // session_id (UUID) - matches PRIMARY KEY
    let userId: String           // user_id (UUID) - matches REFERENCES auth.users(id)
    let tag: String              // tag TEXT NOT NULL - canonical: wake_check, pre_sleep, sleep, experiment
    let subtag: String           // subtag TEXT NOT NULL - auto-assigned per canonical patterns
    let eventId: Int             // event_id INTEGER NOT NULL DEFAULT 0 - always 0 for client, DB assigns for sleep
    let duration: Int            // duration_minutes INTEGER NOT NULL
    let recordedAt: Date         // recorded_at TIMESTAMPTZ NOT NULL
    let rrIntervals: [Double]    // rr_intervals DOUBLE PRECISION[] NOT NULL (milliseconds)
    
    // MARK: - db_schema.sql Compliant Initialization
    init(
        id: String = UUID().uuidString,
        userId: String,
        tag: String,
        subtag: String,
        eventId: Int = 0,  // Always 0 for client per trigger-based allocation
        duration: Int,
        rrIntervals: [Double],
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.tag = tag
        self.subtag = subtag
        self.eventId = eventId  // Always 0, DB trigger handles allocation
        self.duration = duration
        self.rrIntervals = rrIntervals
        self.recordedAt = recordedAt
    }
    
    // MARK: - Canonical API Payload (matches blueprint_recording.md Queue Card JSON)
    func toAPIPayload() -> [String: Any] {
        // ISO8601 formatter with fractional seconds for consistency with API
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return [
            "session_id": id,
            "user_id": userId,
            "tag": tag,
            "subtag": subtag,
            "event_id": 0,  // ALWAYS 0 per trigger-based allocation
            "duration_minutes": duration,
            "recorded_at": formatter.string(from: recordedAt),
            "rr_intervals": rrIntervals,
            "rr_count": rrIntervals.count  // Include for API validation
        ]
    }
    
    // MARK: - Session Logic
    var isSleepInterval: Bool {
        return tag == "sleep" && subtag.starts(with: "sleep_interval_")
    }
    
    var isGroupedSession: Bool {
        return eventId > 0  // Will be true after DB assigns event_id for sleep
    }
    
    // Extract interval number from sleep subtag
    var intervalNumber: Int? {
        guard tag == "sleep", subtag.starts(with: "sleep_interval_") else { return nil }
        let components = subtag.split(separator: "_")
        guard components.count == 3 else { return nil }
        return Int(components[2])
    }
}

// MARK: - HRV Metrics Model (db_schema.sql Compliant - 9 Core Metrics)
struct HRVMetrics: Codable {
    let meanHr: Double?      // mean_hr DOUBLE PRECISION
    let meanRr: Double?      // mean_rr DOUBLE PRECISION
    let countRr: Int?        // rr_count INTEGER NOT NULL (note: DB uses rr_count, not count_rr)
    let rmssd: Double?       // rmssd DOUBLE PRECISION
    let sdnn: Double?        // sdnn DOUBLE PRECISION
    let pnn50: Double?       // pnn50 DOUBLE PRECISION
    let cvRr: Double?        // cv_rr DOUBLE PRECISION
    let defa: Double?        // defa DOUBLE PRECISION
    let sd2Sd1: Double?      // sd2_sd1 DOUBLE PRECISION
    
    enum CodingKeys: String, CodingKey {
        case meanHr = "mean_hr"
        case meanRr = "mean_rr"
        case countRr = "rr_count"  // DB column is rr_count, not count_rr
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

// MARK: - Processed Session Model (db_schema.sql Compliant)
struct ProcessedSession: Codable, Identifiable {
    let sessionId: String        // session_id UUID PRIMARY KEY
    let tag: String              // tag TEXT NOT NULL
    let subtag: String           // subtag TEXT NOT NULL
    let eventId: Int             // event_id INTEGER (from DB after trigger allocation)
    let status: String           // status TEXT NOT NULL DEFAULT 'completed'
    let durationMinutes: Int     // duration_minutes INTEGER NOT NULL
    let recordedAt: Date         // recorded_at TIMESTAMPTZ NOT NULL
    let processedAt: Date?       // processed_at TIMESTAMPTZ (nullable)
    let hrvMetrics: HRVMetrics   // All 9 metrics from DB
    
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

// MARK: - Raw Session Model (db_schema.sql Compliant)
struct RawSession: Codable, Identifiable {
    let sessionId: String        // session_id UUID PRIMARY KEY
    let userId: String           // user_id UUID REFERENCES auth.users(id)
    let tag: String              // tag TEXT NOT NULL
    let subtag: String           // subtag TEXT NOT NULL (canonical patterns)
    let eventId: Int             // event_id INTEGER NOT NULL (from DB)
    let durationMinutes: Int     // duration_minutes INTEGER NOT NULL
    let recordedAt: Date         // recorded_at TIMESTAMPTZ NOT NULL
    let rrIntervals: [Double]    // rr_intervals DOUBLE PRECISION[] NOT NULL
    let rrCount: Int             // rr_count INTEGER NOT NULL
    
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
        case eventId = "event_id"  // Matches DB column name
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
