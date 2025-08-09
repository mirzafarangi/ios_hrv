/**
 * CoreState.swift
 * App-wide observable state for HRV iOS App
 * Canonical compliant with db_schema.sql and blueprint_api.md
 */

import Foundation
import Combine

struct CoreState {
    
    // MARK: - Sensor State
    var sensorInfo: SensorInfo? = nil
    var sensorConnectionState: SensorConnectionState = .disconnected
    var currentHeartRate: Int = 0
    
    // MARK: - Recording State
    var isRecording: Bool = false
    var currentSession: Session? = nil
    var selectedTag: SessionTag = .wakeCheck  // Default to canonical tag
    var selectedDuration: Int = 5 // minutes
    
    // MARK: - Canonical Configuration
    var isPairedMode: Bool = false  // For wake_check/pre_sleep paired mode
    var experimentProtocolName: String? = nil  // For experiment protocol subtag
    var currentSleepIntervalNumber: Int = 1  // Track sleep interval number
    var lastApiEventId: Int? = nil  // Store event_id returned by API for reference
    
    // MARK: - Recording Timer State
    var recordingProgress: Double = 0.0 // 0.0 to 1.0
    var remainingTime: Int = 0 // seconds remaining
    var elapsedTime: Int = 0 // seconds elapsed
    
    // MARK: - Recording Mode State
    var recordingMode: RecordingMode = .single(tag: .wakeCheck, duration: 5)
    // Note: SleepEvent is deprecated - DB trigger handles event_id allocation
    
    // MARK: - Sleep Event Management (Canonical)
    var isInAutoRecordingMode: Bool {
        return recordingMode.isAutoRecording
    }
    
    // MARK: - Queue State
    var queueItems: [QueueItem] = []
    var queueStatus: QueueStatus = .idle
    var isUploading: Bool = false
    
    // MARK: - UI State
    var debugMessages: [String] = []
    var debugLogs: [String] = []  // For detailed debug logs
    var showingDebugLog: Bool = false
    
    // MARK: - Computed Properties
    var canStartRecording: Bool {
        return sensorConnectionState == .connected && !isRecording
    }
    
    var canStopRecording: Bool {
        return isRecording
    }
    
    var hasQueuedItems: Bool {
        return !queueItems.isEmpty
    }
    
    var queueItemCount: Int {
        return queueItems.count
    }
    
    var failedQueueItemCount: Int {
        return queueItems.filter { $0.status == .failed }.count
    }
    
    var hasFailedItems: Bool {
        return queueItems.contains { $0.status == .failed }
    }
    
    var hasCompletedItems: Bool {
        return queueItems.contains { $0.status == .completed }
    }
    
    // MARK: - Debug Helpers
    mutating func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugMessages.append("[\(timestamp)] \(message)")
        
        // Keep only last 20 messages
        if debugMessages.count > 20 {
            debugMessages.removeFirst()
        }
        
        print("🔵 Debug: \(message)")
    }
    
    mutating func clearDebugMessages() {
        debugMessages.removeAll()
    }
}
