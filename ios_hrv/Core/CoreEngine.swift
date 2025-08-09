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
        await authService.signOut()
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
            durationMinutes: duration,
            heartRatePublisher: bleManager.heartRatePublisher,
            isPaired: coreState.isPairedMode,
            intervalNumber: tag == .sleep ? coreState.currentSleepIntervalNumber : nil,
            protocolName: coreState.experimentProtocolName
        )
        
        // Event emission handled by RecordingManager to avoid duplicates
    }
    
    func stopRecording() {
        recordingManager.stopRecording()
        CoreEvents.shared.emit(.recordingStopped)
        CoreLogger.shared.log("Recording stopped by user", category: .recording, level: .info)
    }
    
    // MARK: - Recording Mode Management
    func updateRecordingConfiguration(
        tag: SessionTag,
        duration: Int,
        isPaired: Bool = false,
        protocolName: String? = nil
    ) {
        coreState.selectedTag = tag
        coreState.selectedDuration = duration
        
        // Store additional configuration for subtag generation
        coreState.isPairedMode = isPaired
        coreState.experimentProtocolName = protocolName
        
        // Update recording mode based on tag
        if tag == .sleep {
            // For sleep tag, prepare auto-recording mode with interval tracking
            // NO event_id generation - DB trigger handles this
            coreState.recordingMode = .autoRecording(intervalDuration: duration, currentInterval: 1, dbEventId: nil)
            coreState.currentSleepIntervalNumber = 1
            CoreLogger.shared.log("Configured auto-recording mode for sleep intervals", category: .core, level: .info)
        } else {
            // For other tags, use single recording mode
            coreState.recordingMode = .single(tag: tag, duration: duration, protocolName: protocolName)
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
        case .single(let tag, let duration, _):
            startSingleRecording(tag: tag, duration: duration)
            
        case .autoRecording(let intervalDuration, let currentInterval, _):
            startSleepIntervalRecording(intervalDuration: intervalDuration, intervalNumber: currentInterval)
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
            durationMinutes: duration,
            heartRatePublisher: bleManager.heartRatePublisher,
            isPaired: coreState.isPairedMode,
            intervalNumber: nil,
            protocolName: coreState.experimentProtocolName
        )
    }
    
    private func startSleepIntervalRecording(intervalDuration: Int, intervalNumber: Int) {
        CoreLogger.shared.log("Starting sleep interval \(intervalNumber)", category: .recording, level: .info)
        
        guard userId != nil else {
            CoreLogger.shared.log("Cannot start recording - no authenticated user", category: .recording, level: .error)
            return
        }
        
        // Log sleep interval start (event_id handled by DB trigger)
        
        recordingManager.startRecording(
            tag: .sleep,
            durationMinutes: intervalDuration,
            heartRatePublisher: bleManager.heartRatePublisher,
            isPaired: false,
            intervalNumber: intervalNumber,
            protocolName: nil
        )
        
        // Track interval number for next recording
        coreState.currentSleepIntervalNumber = intervalNumber
    }
    
    func stopAutoRecording() {
        // Stop current recording and end sleep session
        recordingManager.stopRecording()
        
        // Log completion of sleep recording
        CoreLogger.shared.log("Ended sleep recording with \(coreState.currentSleepIntervalNumber) intervals", category: .core, level: .info)
        
        // Reset to single recording mode with canonical default
        coreState.recordingMode = .single(tag: .wakeCheck, duration: 5)
        coreState.currentSleepIntervalNumber = 1  // Reset for next sleep session
        CoreEvents.shared.emit(.autoRecordingStopped)
    }
    
    func onRecordingCompleted() {
        // Called when a recording session completes
        switch coreState.recordingMode {
        case .single:
            // Single recording completed - nothing special to do
            CoreLogger.shared.log("Single recording completed", category: .recording, level: .info)
            
        case .autoRecording(let intervalDuration, let currentInterval, _):
            // Sleep interval completed - automatically start next interval
            CoreLogger.shared.log("Sleep interval \(currentInterval) completed", category: .recording, level: .info)
            
            // Update recording mode for next interval
            coreState.recordingMode = .autoRecording(intervalDuration: intervalDuration, currentInterval: currentInterval + 1, dbEventId: coreState.lastApiEventId)
            coreState.currentSleepIntervalNumber = currentInterval + 1
            CoreLogger.shared.log("Updated recording mode for next interval: \(currentInterval + 1)", category: .core, level: .info)
            
            // AUTOMATICALLY start the next interval immediately
            // This creates the continuous sleep recording flow: interval_1 → interval_2 → interval_3 → ...
            Task { @MainActor in
                if self.coreState.isInAutoRecordingMode {
                    self.startSleepIntervalRecording(intervalDuration: intervalDuration, intervalNumber: currentInterval + 1)
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
    
    // MARK: - Session Processing
    func processCompletedSession(_ session: Session) {
        // Store any event_id returned by the API for sleep sessions
        if session.tag == SessionTag.sleep.rawValue {
            // The API will return the DB-assigned event_id in the response
            // We'll store it for reference but always send event_id=0 in uploads
            CoreLogger.shared.log("Sleep session will receive event_id from DB trigger", category: .core, level: .info)
        }
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
    
    func clearCompletedFromQueue() {
        queueManager.clearCompletedItems()
        CoreLogger.shared.log("Completed items cleared from queue", category: .queue, level: .info)
    }
    
    // MARK: - Session Processing (Simple Counter Only)
    func incrementSessionsProcessed() {
        totalSessionsProcessed += 1
        CoreLogger.shared.log("Session processing completed (Total: \(totalSessionsProcessed))", category: .core, level: .info)
    }
}
