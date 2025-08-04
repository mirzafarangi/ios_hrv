/**
 * Enums.swift
 * Shared enumerations for HRV iOS App
 * Keeps logic consistent across components
 */

import Foundation

// MARK: - Session Tag
enum SessionTag: String, CaseIterable, Codable {
    case rest = "rest"
    case sleep = "sleep"
    case experimentPairedPre = "experiment_paired_pre"
    case experimentPairedPost = "experiment_paired_post"
    case experimentalDuration = "experimental_duration"
    
    var displayName: String {
        switch self {
        case .rest:
            return "Rest"
        case .sleep:
            return "Sleep"
        case .experimentPairedPre:
            return "Experiment Paired Pre"
        case .experimentPairedPost:
            return "Experiment Paired Post"
        case .experimentalDuration:
            return "Experimental Duration"
        }
    }
    
    var icon: String {
        switch self {
        case .rest:
            return "heart.fill"
        case .sleep:
            return "moon.fill"
        case .experimentPairedPre:
            return "flask.fill"
        case .experimentPairedPost:
            return "checkmark.circle.fill"
        case .experimentalDuration:
            return "timer.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .rest:
            return "Resting HRV measurement"
        case .sleep:
            return "Sleep HRV recording with auto-intervals"
        case .experimentPairedPre:
            return "Pre-experiment baseline measurement"
        case .experimentPairedPost:
            return "Post-experiment measurement"
        case .experimentalDuration:
            return "Extended experimental measurement"
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
        case .rest:
            return 7
        case .sleep:
            return 7  // Per interval
        case .experimentPairedPre, .experimentPairedPost:
            return 5
        case .experimentalDuration:
            return 15
        }
    }
    
    var minDurationMinutes: Int {
        return 1
    }
    
    var maxDurationMinutes: Int {
        return 60
    }
}

// MARK: - Recording Mode
enum RecordingMode: Equatable {
    case single(tag: SessionTag, duration: Int)
    case autoRecording(sleepEventId: Int, intervalDuration: Int, currentInterval: Int)
    
    var tag: SessionTag {
        switch self {
        case .single(let tag, _):
            return tag
        case .autoRecording(_, _, _):
            return .sleep
        }
    }
    
    var duration: Int {
        switch self {
        case .single(_, let duration):
            return duration
        case .autoRecording(_, let intervalDuration, _):
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
        case .single(let tag, let duration):
            return "\(tag.displayName) - \(duration) min"
        case .autoRecording(let eventId, let duration, let interval):
            return "Sleep Event \(eventId) - Interval \(interval) (\(duration) min)"
        }
    }
}

// MARK: - Sleep Event Management
struct SleepEvent: Codable, Identifiable {
    let id: Int  // 1001, 1002, 1003, etc.
    let startedAt: Date
    var endedAt: Date?
    var intervalCount: Int
    var isActive: Bool
    
    init(id: Int) {
        self.id = id
        self.startedAt = Date()
        self.endedAt = nil
        self.intervalCount = 0
        self.isActive = true
    }
    
    mutating func addInterval() {
        intervalCount += 1
    }
    
    mutating func end() {
        endedAt = Date()
        isActive = false
    }
    
    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}

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
    
    init(session: Session) {
        self.id = session.id
        self.session = session
        self.status = .pending
        self.createdAt = Date()
        self.lastAttemptAt = nil
        self.attemptCount = 0
        self.errorMessage = nil
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
