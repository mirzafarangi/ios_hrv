/**
 * CoreState.swift
 * App-wide observable state for HRV iOS App
 * Holds all shared state bound to SwiftUI views
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
    var selectedTag: SessionTag = .rest
    var selectedDuration: Int = 5 // minutes
    
    // MARK: - Recording Timer State
    var recordingProgress: Double = 0.0 // 0.0 to 1.0
    var remainingTime: Int = 0 // seconds remaining
    var elapsedTime: Int = 0 // seconds elapsed
    
    // MARK: - Recording Mode State
    var recordingMode: RecordingMode = .single(tag: .rest, duration: 5)
    var currentSleepEvent: SleepEvent? = nil
    var sleepEventHistory: [SleepEvent] = []
    
    // MARK: - Sleep Event Management
    var nextSleepEventId: Int {
        // Start from 1001, increment based on history
        let maxId = sleepEventHistory.map { $0.id }.max() ?? 1000
        return maxId + 1
    }
    
    var isInAutoRecordingMode: Bool {
        return recordingMode.isAutoRecording
    }
    
    var currentSleepIntervalNumber: Int {
        if case .autoRecording(_, _, let interval) = recordingMode {
            return interval
        }
        return 0
    }
    
    // MARK: - Queue State
    var queueItems: [QueueItem] = []
    var queueStatus: QueueStatus = .idle
    
    // MARK: - UI State
    var debugMessages: [String] = []
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
