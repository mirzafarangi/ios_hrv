/**
 * CoreEvents.swift
 * Standardized system events and triggers for HRV iOS App
 * Improves coordination and debugging across components
 */

import Foundation
import Combine

// MARK: - Event Types
enum CoreEvent {
    // Sensor Events
    case sensorConnectionRequested
    case sensorConnected(deviceName: String)
    case sensorDisconnected
    case sensorConnectionFailed(error: String)
    
    // Recording Events
    case recordingStarted(tag: SessionTag, duration: Int)
    case recordingStopped
    case recordingCompleted(session: Session)
    case recordingFailed(error: String)
    
    // Recording Mode Events
    case recordingConfigurationChanged
    case autoRecordingStarted(intervalNumber: Int)
    case autoRecordingStopped
    case sleepIntervalCompleted(eventId: Int, intervalNumber: Int)
    case sleepEventCreated(eventId: Int)
    case sleepEventEnded(eventId: Int, totalIntervals: Int)
    
    // Authentication Events
    case userSignedIn
    case userSignedUp
    case userSignedOut
    case authenticationFailed(error: String)
    
    // Queue Events
    case sessionQueued(sessionId: String)
    case sessionUploadStarted(sessionId: String)
    case sessionUploadCompleted(sessionId: String)
    case sessionUploadFailed(sessionId: String, error: String)
    case queueRetryRequested
    case queueCleared
    
    // System Events
    case appLaunched
    case appWillTerminate
    case debugLogRequested
}

// MARK: - Event Manager
class CoreEvents: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoreEvents()
    
    // MARK: - Publishers
    private let eventSubject = PassthroughSubject<CoreEvent, Never>()
    
    var eventPublisher: AnyPublisher<CoreEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Init
    private init() {
        print("🔧 CoreEvents initialized")
    }
    
    // MARK: - Public Interface
    func emit(_ event: CoreEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSubject.send(event)
            self?.logEvent(event)
        }
    }
    
    // MARK: - Event Logging
    private func logEvent(_ event: CoreEvent) {
        let eventDescription = describeEvent(event)
        print("📡 Event: \(eventDescription)")
        
        // Add to debug log if needed
        Task { @MainActor in
            CoreEngine.shared.coreState.addDebugMessage("Event: \(eventDescription)")
        }
    }
    
    private func describeEvent(_ event: CoreEvent) -> String {
        switch event {
        case .sensorConnectionRequested:
            return "Sensor connection requested"
        case .sensorConnected(let deviceName):
            return "Sensor connected: \(deviceName)"
        case .sensorDisconnected:
            return "Sensor disconnected"
        case .sensorConnectionFailed(let error):
            return "Sensor connection failed: \(error)"
            
        case .recordingStarted(let tag, let duration):
            return "Recording started: \(tag.rawValue), \(duration)min"
        case .recordingStopped:
            return "Recording stopped"
        case .recordingCompleted(let session):
            return "Recording completed: \(session.id)"
        case .recordingFailed(let error):
            return "Recording failed: \(error)"
            
        // Recording Mode Events
        case .recordingConfigurationChanged:
            return "Recording configuration changed"
        case .autoRecordingStarted(let intervalNumber):
            return "Auto-recording started: Sleep Interval \(intervalNumber)"
        case .autoRecordingStopped:
            return "Auto-recording stopped"
        case .sleepIntervalCompleted(let eventId, let intervalNumber):
            return "Sleep interval completed: Event \(eventId), Interval \(intervalNumber)"
        case .sleepEventCreated(let eventId):
            return "Sleep event created: \(eventId)"
        case .sleepEventEnded(let eventId, let totalIntervals):
            return "Sleep event ended: \(eventId) (\(totalIntervals) intervals)"
            
        // Authentication Events
        case .userSignedIn:
            return "User signed in"
        case .userSignedUp:
            return "User signed up"
        case .userSignedOut:
            return "User signed out"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error)"
            
        case .sessionQueued(let sessionId):
            return "Session queued: \(sessionId)"
        case .sessionUploadStarted(let sessionId):
            return "Upload started: \(sessionId)"
        case .sessionUploadCompleted(let sessionId):
            return "Upload completed: \(sessionId)"
        case .sessionUploadFailed(let sessionId, let error):
            return "Upload failed: \(sessionId) - \(error)"
        case .queueRetryRequested:
            return "Queue retry requested"
        case .queueCleared:
            return "Queue cleared"
            
        case .appLaunched:
            return "App launched"
        case .appWillTerminate:
            return "App will terminate"
        case .debugLogRequested:
            return "Debug log requested"
        }
    }
}
