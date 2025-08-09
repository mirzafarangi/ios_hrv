/**
 * Enums.swift
 * Shared enumerations for HRV iOS App
 * Keeps logic consistent across components
 */

import Foundation

// MARK: - Session Tag (Canonical - matches db_schema.sql)
enum SessionTag: String, CaseIterable, Codable {
    case wakeCheck = "wake_check"
    case preSleep = "pre_sleep"
    case sleep = "sleep"
    case experiment = "experiment"
    
    var displayName: String {
        switch self {
        case .wakeCheck:
            return "Wake Check"
        case .preSleep:
            return "Pre-Sleep"
        case .sleep:
            return "Sleep"
        case .experiment:
            return "Experiment"
        }
    }
    
    var icon: String {
        switch self {
        case .wakeCheck:
            return "sunrise.fill"
        case .preSleep:
            return "moon.stars.fill"
        case .sleep:
            return "moon.fill"
        case .experiment:
            return "flask.fill"
        }
    }
    
    var description: String {
        switch self {
        case .wakeCheck:
            return "Morning wake check HRV measurement"
        case .preSleep:
            return "Pre-sleep HRV measurement"
        case .sleep:
            return "Sleep HRV recording with auto-intervals"
        case .experiment:
            return "Experimental protocol measurement"
        }
    }
    
    // MARK: - Recording Mode Logic
    var isAutoRecordingMode: Bool {
        return self == .sleep
    }
    
    var isSingleRecordingMode: Bool {
        return !isAutoRecordingMode
    }
    
    var defaultDurationMinutes: Int {
        switch self {
        case .wakeCheck:
            return 5
        case .preSleep:
            return 5
        case .sleep:
            return 7  // Per interval
        case .experiment:
            return 10
        }
    }
    
    var minDurationMinutes: Int {
        return 1
    }
    
    var maxDurationMinutes: Int {
        return 60
    }
    
    // MARK: - Canonical Subtag Generation (matches db_schema.sql constraints)
    func generateSubtag(isPaired: Bool = false, intervalNumber: Int? = nil, protocolName: String? = nil) -> String {
        switch self {
        case .wakeCheck:
            // wake_check_(single|paired_day_pre)
            return isPaired ? "wake_check_paired_day_pre" : "wake_check_single"
            
        case .preSleep:
            // pre_sleep_(single|paired_day_post)
            return isPaired ? "pre_sleep_paired_day_post" : "pre_sleep_single"
            
        case .sleep:
            // sleep_interval_[1-9][0-9]*
            let interval = intervalNumber ?? 1
            return "sleep_interval_\(interval)"
            
        case .experiment:
            // experiment_(single|protocol_[a-z0-9_]+)
            if let protocolStr = protocolName, !protocolStr.isEmpty {
                // Sanitize protocol name to match regex: [a-z0-9_]+
                let sanitized = protocolStr.lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "-", with: "_")
                    .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                return "experiment_protocol_\(sanitized)"
            } else {
                return "experiment_single"
            }
        }
    }
}

// MARK: - Recording Mode (Canonical)
enum RecordingMode: Equatable {
    case single(tag: SessionTag, duration: Int, protocolName: String? = nil)
    case autoRecording(intervalDuration: Int, currentInterval: Int, dbEventId: Int? = nil)
    
    var tag: SessionTag {
        switch self {
        case .single(let tag, _, _):
            return tag
        case .autoRecording(_, _, _):
            return .sleep
        }
    }
    
    var duration: Int {
        switch self {
        case .single(_, let duration, _):
            return duration
        case .autoRecording(let intervalDuration, _, _):
            return intervalDuration
        }
    }
    
    var isAutoRecording: Bool {
        switch self {
        case .single:
            return false
        case .autoRecording:
            return true
        }
    }
    
    var displayText: String {
        switch self {
        case .single(let tag, let duration, let protocolName):
            if let protocolStr = protocolName {
                return "\(tag.displayName) (\(protocolStr)) - \(duration) min"
            }
            return "\(tag.displayName) - \(duration) min"
        case .autoRecording(let duration, let interval, let dbEventId):
            if let eventId = dbEventId {
                return "Sleep Event \(eventId) - Interval \(interval) (\(duration) min)"
            }
            return "Sleep Recording - Interval \(interval) (\(duration) min)"
        }
    }
}

// MARK: - Sleep Event Management
// Note: Event ID allocation is handled entirely by DB trigger.
// The iOS app always sends event_id=0 for all sessions.
// For sleep sessions, the DB assigns and returns the appropriate event_id.

// MARK: - Sensor Connection State
enum SensorConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case failed(String)
    
    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected:
            return "bluetooth.slash"
        case .scanning:
            return "bluetooth"
        case .connecting:
            return "bluetooth"
        case .connected:
            return "bluetooth.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

// MARK: - Recording Mode (Removed duplicate - using comprehensive implementation above)

// MARK: - Queue Status
enum QueueStatus: Equatable {
    case idle
    case uploading
    case retrying
    case failed(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .uploading:
            return "Uploading..."
        case .retrying:
            return "Retrying..."
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    var icon: String {
        switch self {
        case .idle:
            return "tray"
        case .uploading:
            return "arrow.up.circle.fill"
        case .retrying:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Queue Item Status
enum QueueItemStatus: String, Codable {
    case pending = "pending"
    case uploading = "uploading"
    case completed = "completed"
    case failed = "failed"
    
    var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock"
        case .uploading:
            return "arrow.up.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Queue Item
struct QueueItem: Identifiable, Codable {
    let id: String
    let session: Session
    var status: QueueItemStatus
    let createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var errorMessage: String?
    var validationReport: [String: Any]?
    var dbStatus: String?
    
    init(session: Session) {
        self.id = session.id
        self.session = session
        self.status = .pending
        self.createdAt = Date()
        self.lastAttemptAt = nil
        self.attemptCount = 0
        self.errorMessage = nil
        self.validationReport = nil
        self.dbStatus = nil
    }
    
    var displayName: String {
        // Generate display name from tag and subtag (schema.md compliant)
        if session.tag == "sleep" && session.subtag.starts(with: "sleep_interval_") {
            return "Sleep Interval"
        } else {
            return session.tag.capitalized
        }
    }
    
    var statusDescription: String {
        switch status {
        case .pending:
            return "Waiting to upload"
        case .uploading:
            return "Uploading to server..."
        case .completed:
            return "Successfully uploaded"
        case .failed:
            if let error = errorMessage {
                return "Failed: \(error)"
            } else {
                return "Upload failed"
            }
        }
    }
}
