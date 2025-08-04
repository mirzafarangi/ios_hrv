/**
 * RecordingManager.swift
 * Recording session manager for HRV iOS App
 * Controls manual and timed recording logic, session timing, and state transitions
 */

import Foundation
import Combine

class RecordingManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var currentSession: Session?
    @Published var recordingProgress: Double = 0.0 // 0.0 to 1.0
    @Published var remainingTime: Int = 0 // seconds remaining
    @Published var elapsedTime: Int = 0 // seconds elapsed
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var progressTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingDuration: Int = 0 // minutes
    private var recordingTag: SessionTag = .rest
    private var heartRateData: [Double] = []
    private var heartRateSubscription: AnyCancellable?
    
    // MARK: - Constants
    private let minimumRecordingDuration: TimeInterval = 30 // 30 seconds minimum
    
    // MARK: - Initialization
    init() {
        print("🔧 RecordingManager initialized")
    }
    
    // MARK: - Public Interface
    @MainActor
    func startRecording(
        tag: SessionTag, 
        duration: TimeInterval, 
        heartRatePublisher: AnyPublisher<Int, Never>,
        subtag: String? = nil,
        sleepEventId: Int? = nil
    ) {
        guard !isRecording else {
            logWarning("Recording already in progress", category: .recording)
            return
        }
        
        logFlowStart("Recording Session", category: .recording)
        logInfo("Session initiated: tag=\(tag.rawValue), duration=\(duration)s", category: .recording)
        
        // Get authenticated user ID
        guard let userId = SupabaseAuthService.shared.userId else {
            logError("Cannot start recording - user not authenticated", category: .recording)
            return
        }
        
        // Setup recording state
        recordingTag = tag
        recordingDuration = Int(duration)
        recordingStartTime = Date()
        heartRateData.removeAll()
        isRecording = true
        
        // Subscribe to heart rate data
        heartRateSubscription = heartRatePublisher
            .sink { [weak self] heartRate in
                self?.processHeartRateData(heartRate)
            }
        
        // Create current session for UI display (Unified Schema)
        currentSession = Session(
            userId: userId,
            tag: tag.rawValue,              // Convert SessionTag to string
            subtag: subtag ?? "\(tag.rawValue)_single", // Default subtag for non-sleep
            eventId: sleepEventId ?? 0,     // 0 for non-grouped sessions
            duration: Int(duration),
            rrIntervals: []
        )
        
        // Setup timer for automatic stop
        setupRecordingTimer(duration: Int(duration))
        
        logFlowStep("Recording Session", step: "Event emission", category: .recording)
        CoreEvents.shared.emit(.recordingStarted(tag: tag, duration: Int(duration)))
    }
    
    func stopRecording() {
        guard isRecording else {
            logWarning("No recording in progress", category: .recording)
            return
        }
        
        logFlowStep("Recording Session", step: "Stop initiated", category: .recording)
        
        // Stop all timers and subscriptions
        recordingTimer?.invalidate()
        recordingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        heartRateSubscription?.cancel()
        heartRateSubscription = nil
        
        // Reset timer state
        recordingProgress = 0.0
        remainingTime = 0
        elapsedTime = 0
        
        // Calculate actual duration
        let actualDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Validate recording
        if actualDuration < minimumRecordingDuration {
            logError("Recording too short: \(actualDuration)s (minimum: \(minimumRecordingDuration)s)", category: .recording)
            
            isRecording = false
            currentSession = nil
            
            CoreEvents.shared.emit(.recordingFailed(error: "Recording too short"))
            return
        }
        
        if heartRateData.count < 10 {
            logError("Insufficient heart rate data: \(heartRateData.count) readings", category: .recording)
            
            isRecording = false
            currentSession = nil
            
            CoreEvents.shared.emit(.recordingFailed(error: "Insufficient heart rate data"))
            return
        }
        
        // Create completed session (Unified Schema)
        let completedSession = Session(
            id: currentSession?.id ?? UUID().uuidString,
            userId: currentSession?.userId ?? "",
            tag: currentSession?.tag ?? recordingTag.rawValue,
            subtag: currentSession?.subtag ?? "\(recordingTag.rawValue)_single",
            eventId: currentSession?.eventId ?? 0,
            duration: recordingDuration,
            rrIntervals: heartRateData,
            recordedAt: recordingStartTime ?? Date()
        )
        
        logInfo("Recording completed: hr_readings=\(heartRateData.count), rr_intervals=\(heartRateData.count)", category: .recording)
        
        // Update state
        isRecording = false
        currentSession = nil
        
        // Notify completion
        CoreEvents.shared.emit(.recordingCompleted(session: completedSession))
        
        // Add to queue via CoreEngine
        Task { @MainActor in
            CoreEngine.shared.processCompletedSession(completedSession)
        }
    }
    
    // MARK: - Private Methods
    private func setupRecordingTimer(duration: Int) {
        let totalSeconds = duration * 60
        remainingTime = totalSeconds
        elapsedTime = 0
        recordingProgress = 0.0
        
        // Main recording timer - auto-stops after duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(totalSeconds), repeats: false) { [weak self] _ in
            logInfo("Recording timer expired - initiating auto-stop", category: .recording)
            Task { @MainActor in
                self?.stopRecording()
            }
        }
        
        // Progress timer - updates every second
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
        
        logInfo("Recording timer setup: \(duration) minutes (\(totalSeconds) seconds)", category: .recording)
    }
    
    @MainActor
    private func updateProgress() {
        guard isRecording, let startTime = recordingStartTime else { return }
        
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let totalDuration = recordingDuration * 60
        
        elapsedTime = elapsed
        remainingTime = max(0, totalDuration - elapsed)
        recordingProgress = min(1.0, Double(elapsed) / Double(totalDuration))
        
        // Update current session heart rate count for UI (Unified Schema)
        if let session = currentSession {
            currentSession = Session(
                id: session.id,
                userId: session.userId,
                tag: session.tag,
                subtag: session.subtag,
                eventId: session.eventId,
                duration: session.duration,
                rrIntervals: heartRateData,
                recordedAt: session.recordedAt
            )
        }
    }
    
    private func processHeartRateData(_ heartRate: Int) {
        guard isRecording else { return }
        
        // Validate heart rate to prevent infinite/NaN RR intervals
        guard heartRate > 0 && heartRate <= 300 else {
            print("⚠️ Invalid heart rate: \(heartRate) BPM - skipping")
            return
        }
        
        // Convert heart rate to RR interval (simplified)
        // In a real implementation, you'd get actual RR intervals from the sensor
        let rrInterval = 60000.0 / Double(heartRate) // Convert BPM to ms
        
        // Additional validation for RR interval range (300-2000ms is typical)
        guard rrInterval >= 300 && rrInterval <= 2000 && rrInterval.isFinite else {
            print("⚠️ Invalid RR interval: \(rrInterval)ms from HR: \(heartRate) BPM - skipping")
            return
        }
        
        heartRateData.append(rrInterval)
        
        // Update current session for UI (Unified Schema)
        if let session = currentSession {
            currentSession = Session(
                id: session.id,
                userId: session.userId,
                tag: session.tag,
                subtag: session.subtag,
                eventId: session.eventId,
                duration: session.duration,
                rrIntervals: heartRateData,
                recordedAt: session.recordedAt
            )
        }
        
        print("💓 HR: \(heartRate) BPM, RR: \(String(format: "%.1f", rrInterval))ms (\(heartRateData.count) readings)")
    }
    
    // MARK: - Computed Properties
    // Note: recordingProgress is now a @Published property, not computed
    
    var recordingTimeRemaining: TimeInterval {
        guard isRecording,
              let startTime = recordingStartTime else {
            return 0.0
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let total = TimeInterval(recordingDuration * 60)
        
        return max(total - elapsed, 0.0)
    }
    
    var recordingTimeRemainingText: String {
        let remaining = recordingTimeRemaining
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}
