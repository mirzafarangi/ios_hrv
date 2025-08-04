/**
 * CoreEngine.swift
 * Master orchestrator for HRV iOS App
 * Coordinates BLE, recording, queueing, and backend sync
 */

import Foundation
import Combine
import SwiftUI

@MainActor
class CoreEngine: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoreEngine()
    
    // MARK: - Core Managers
    private let authService: SupabaseAuthService
    private let bleManager: BLEManager
    private let recordingManager: RecordingManager
    private let queueManager: QueueManager
    private let apiClient: APIClient
    
    // MARK: - Published State
    @Published var coreState = CoreState()
    
    // MARK: - Authentication State (managed by CoreEngine)
    @Published var isAuthenticated = false
    @Published var currentUser: String?
    @Published var userEmail: String?
    @Published var userId: String?
    
    // MARK: - Statistics (Simple Counters Only)
    @Published var totalSessionsProcessed: Int = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        // Initialize authentication first (use singleton)
        self.authService = SupabaseAuthService.shared
        
        // Initialize other managers
        self.bleManager = BLEManager()
        self.recordingManager = RecordingManager()
        self.queueManager = QueueManager()
        self.apiClient = APIClient()
        
        // Setup bindings
        setupBindings()
        
        print("🔧 CoreEngine initialized with authentication")
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Authentication Service -> Core State
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        authService.$userEmail
            .receive(on: DispatchQueue.main)
            .assign(to: \.userEmail, on: self)
            .store(in: &cancellables)
        
        authService.$userId
            .receive(on: DispatchQueue.main)
            .assign(to: \.userId, on: self)
            .store(in: &cancellables)
        
        // BLE Manager -> Core State
        bleManager.$sensorInfo
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.sensorInfo, on: self)
            .store(in: &cancellables)
        
        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.sensorConnectionState, on: self)
            .store(in: &cancellables)
        
        bleManager.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.currentHeartRate, on: self)
            .store(in: &cancellables)
        
        // Recording Manager -> Core State
        recordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.isRecording, on: self)
            .store(in: &cancellables)
        
        recordingManager.$currentSession
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.currentSession, on: self)
            .store(in: &cancellables)
        
        // Recording Timer Properties -> Core State
        recordingManager.$recordingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.recordingProgress, on: self)
            .store(in: &cancellables)
        
        recordingManager.$remainingTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.remainingTime, on: self)
            .store(in: &cancellables)
        
        recordingManager.$elapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.elapsedTime, on: self)
            .store(in: &cancellables)
        
        // Queue Manager -> Core State
        queueManager.$queueItems
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.queueItems, on: self)
            .store(in: &cancellables)
        
        queueManager.$queueStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.coreState.queueStatus, on: self)
            .store(in: &cancellables)
        
        // CoreEvents -> Recording Completion Handler
        CoreEvents.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .recordingCompleted(_):
                    self?.onRecordingCompleted()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    // Authentication Control (managed by CoreEngine)
    func signIn(email: String, password: String) async throws {
        try await authService.signIn(email: email, password: password)
        CoreEvents.shared.emit(.userSignedIn)
    }
    
    func signUp(email: String, password: String) async throws {
        try await authService.signUp(email: email, password: password)
        CoreEvents.shared.emit(.userSignedUp)
    }
    
    func signOut() async throws {
        try await authService.signOut()
        CoreEvents.shared.emit(.userSignedOut)
    }
    
    func resetPassword(email: String) async throws {
        try await authService.resetPassword(email: email)
    }
    
    // Sensor Control
    func connectSensor() {
        bleManager.startScanning()
        CoreEvents.shared.emit(.sensorConnectionRequested)
    }
    
    func disconnectSensor() {
        bleManager.disconnect()
        CoreEvents.shared.emit(.sensorDisconnected)
    }
    
    // Recording Control
    func startRecording(tag: SessionTag, duration: Int) {
        guard coreState.sensorConnectionState == .connected else {
            print("❌ Cannot start recording: sensor not connected")
            return
        }
        
        recordingManager.startRecording(
            tag: tag,
            duration: TimeInterval(duration),
            heartRatePublisher: bleManager.heartRatePublisher
        )
        
        // Event emission handled by RecordingManager to avoid duplicates
    }
    
    func stopRecording() {
        recordingManager.stopRecording()
        CoreEvents.shared.emit(.recordingStopped)
        CoreLogger.shared.log("Recording stopped by user", category: .recording, level: .info)
    }
    
    // MARK: - Recording Mode Management
    func updateRecordingConfiguration(tag: SessionTag, duration: Int) {
        coreState.selectedTag = tag
        coreState.selectedDuration = duration
        
        // Update recording mode based on tag
        if tag.isAutoRecordingMode {
            // For sleep tag, prepare auto-recording mode
            let sleepEventId = coreState.nextSleepEventId
            coreState.recordingMode = .autoRecording(sleepEventId: sleepEventId, intervalDuration: duration, currentInterval: 1)
            CoreLogger.shared.log("Configured auto-recording mode for sleep event \(sleepEventId)", category: .core, level: .info)
        } else {
            // For other tags, use single recording mode
            coreState.recordingMode = .single(tag: tag, duration: duration)
            CoreLogger.shared.log("Configured single recording mode for \(tag.displayName)", category: .core, level: .info)
        }
        
        CoreEvents.shared.emit(.recordingConfigurationChanged)
    }
    
    func startRecordingWithCurrentMode() {
        guard coreState.canStartRecording else {
            CoreLogger.shared.log("Cannot start recording - conditions not met", category: .core, level: .warning)
            return
        }
        
        switch coreState.recordingMode {
        case .single(let tag, let duration):
            startSingleRecording(tag: tag, duration: duration)
            
        case .autoRecording(let sleepEventId, let intervalDuration, let currentInterval):
            startSleepIntervalRecording(sleepEventId: sleepEventId, intervalDuration: intervalDuration, intervalNumber: currentInterval)
        }
    }
    
    private func startSingleRecording(tag: SessionTag, duration: Int) {
        CoreLogger.shared.log("Starting single recording: \(tag.displayName) for \(duration) minutes", category: .recording, level: .info)
        
        guard userId != nil else {
            CoreLogger.shared.log("Cannot start recording - no authenticated user", category: .recording, level: .error)
            return
        }
        
        recordingManager.startRecording(
            tag: tag,
            duration: TimeInterval(duration), // Duration is already in minutes
            heartRatePublisher: bleManager.heartRatePublisher,
            subtag: nil,
            sleepEventId: nil
        )
    }
    
    private func startSleepIntervalRecording(sleepEventId: Int, intervalDuration: Int, intervalNumber: Int) {
        CoreLogger.shared.log("Starting sleep interval \(intervalNumber) for event \(sleepEventId)", category: .recording, level: .info)
        
        guard userId != nil else {
            CoreLogger.shared.log("Cannot start recording - no authenticated user", category: .recording, level: .error)
            return
        }
        
        // Create or update sleep event
        if coreState.currentSleepEvent == nil {
            let newSleepEvent = SleepEvent(id: sleepEventId)
            coreState.currentSleepEvent = newSleepEvent
            CoreLogger.shared.log("Created new sleep event \(sleepEventId)", category: .core, level: .info)
        }
        
        // Generate subtag for this interval
        let subtag = "sleep_interval_\(intervalNumber)"
        
        recordingManager.startRecording(
            tag: .sleep,
            duration: TimeInterval(intervalDuration), // Duration is already in minutes
            heartRatePublisher: bleManager.heartRatePublisher,
            subtag: subtag,
            sleepEventId: sleepEventId
        )
    }
    
    func stopAutoRecording() {
        // Stop current recording and end sleep event
        recordingManager.stopRecording()
        
        if var sleepEvent = coreState.currentSleepEvent {
            sleepEvent.end()
            coreState.sleepEventHistory.append(sleepEvent)
            coreState.currentSleepEvent = nil
            
            CoreLogger.shared.log("Ended sleep event \(sleepEvent.id) with \(sleepEvent.intervalCount) intervals", category: .core, level: .info)
        }
        
        // Reset to single recording mode
        coreState.recordingMode = .single(tag: .rest, duration: 7)
        CoreEvents.shared.emit(.autoRecordingStopped)
    }
    
    func onRecordingCompleted() {
        // Called when a recording session completes
        switch coreState.recordingMode {
        case .single:
            // Single recording completed - nothing special to do
            CoreLogger.shared.log("Single recording completed", category: .recording, level: .info)
            
        case .autoRecording(let sleepEventId, let intervalDuration, let currentInterval):
            // Sleep interval completed - update sleep event and automatically start next interval
            if var sleepEvent = coreState.currentSleepEvent {
                sleepEvent.addInterval()
                coreState.currentSleepEvent = sleepEvent
                
                CoreEvents.shared.emit(.sleepIntervalCompleted(eventId: sleepEventId, intervalNumber: currentInterval))
                CoreLogger.shared.log("Sleep interval \(currentInterval) completed for event \(sleepEventId)", category: .recording, level: .info)
            }
            
            // Update recording mode for next interval and AUTO-START immediately
            let nextInterval = currentInterval + 1
            coreState.recordingMode = .autoRecording(sleepEventId: sleepEventId, intervalDuration: intervalDuration, currentInterval: nextInterval)
            
            CoreLogger.shared.log("Auto-starting sleep interval \(nextInterval) for event \(sleepEventId)", category: .recording, level: .info)
            
            // AUTOMATICALLY start the next interval immediately
            // This creates the continuous sleep recording flow: interval_1 → interval_2 → interval_3 → ...
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.coreState.isInAutoRecordingMode {
                    self.startSleepIntervalRecording(sleepEventId: sleepEventId, intervalDuration: intervalDuration, intervalNumber: nextInterval)
                }
            }
        }
    }
    
    // Queue Management
    func getUploadQueueCount() -> Int {
        return queueManager.queueItems.count
    }
    
    func processUploadQueue() {
        queueManager.retryFailedUploads()
        CoreLogger.shared.log("Processing upload queue (\(queueManager.queueItems.count) items)", category: .queue, level: .info)
    }
    
    func clearUploadQueue() {
        queueManager.clearQueue()
        CoreLogger.shared.log("Upload queue cleared", category: .queue, level: .warning)
    }
    
    func processCompletedSession(_ session: Session) {
        queueManager.addSession(session)
        CoreEvents.shared.emit(.sessionQueued(sessionId: session.id))
    }
    
    func retryFailedUploads() {
        queueManager.retryFailedUploads()
        CoreEvents.shared.emit(.queueRetryRequested)
    }
    
    func clearQueue() {
        queueManager.clearQueue()
        CoreEvents.shared.emit(.queueCleared)
        CoreLogger.shared.log("Queue cleared by user", category: .queue, level: .warning)
    }
    
    // MARK: - Session Processing (Simple Counter Only)
    func incrementSessionsProcessed() {
        totalSessionsProcessed += 1
        CoreLogger.shared.log("Session processing completed (Total: \(totalSessionsProcessed))", category: .core, level: .info)
    }
}
