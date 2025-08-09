/**
 * RecordingManager.swift
 * Recording session manager for HRV iOS App
 * Canonical compliant with db_schema.sql - always sends event_id=0
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
    private var recordingTag: SessionTag = .wakeCheck  // Default to canonical tag
    private var heartRateData: [Double] = []
    private var heartRateSubscription: AnyCancellable?
    private var currentSubtag: String = ""  // Store generated subtag
    private var currentIntervalNumber: Int = 1  // For sleep intervals
    
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
        durationMinutes: Int,
        heartRatePublisher: AnyPublisher<Int, Never>,
        isPaired: Bool = false,
        intervalNumber: Int? = nil,
        protocolName: String? = nil
    ) {
        guard !isRecording else {
            logWarning("Recording already in progress", category: .recording)
            return
        }
        
        logFlowStart("Recording Session", category: .recording)
        logInfo("Session initiated: tag=\(tag.rawValue), duration=\(durationMinutes)m", category: .recording)
        
        // Start auth persistence monitoring for long recordings
        AuthPersistenceManager.shared.recordingDidStart()
        
        // Get authenticated user ID
        guard let userId = SupabaseAuthService.shared.userId else {
            logError("Cannot start recording - user not authenticated", category: .recording)
            return
        }
        
        // Setup recording state
        recordingTag = tag
        recordingDuration = durationMinutes
        recordingStartTime = Date()
        heartRateData.removeAll()
        isRecording = true
        
        // Generate canonical subtag based on tag and context
        currentIntervalNumber = intervalNumber ?? 1
        currentSubtag = tag.generateSubtag(
            isPaired: isPaired,
            intervalNumber: tag == .sleep ? currentIntervalNumber : nil,
            protocolName: protocolName
        )
        
        logInfo("Generated canonical subtag: \(currentSubtag)", category: .recording)
        
        // Subscribe to heart rate data
        heartRateSubscription = heartRatePublisher
            .sink { [weak self] heartRate in
                self?.processHeartRateData(heartRate)
            }
        
        // Create current session for UI display (Canonical compliant)
        // Note: duration here is the CONFIGURED duration in MINUTES
        currentSession = Session(
            userId: userId,
            tag: tag.rawValue,              // Canonical tag as string
            subtag: currentSubtag,          // Generated canonical subtag
            eventId: 0,                     // ALWAYS 0 - DB trigger handles allocation
            duration: durationMinutes,      // Duration in MINUTES as per API/DB schema
            rrIntervals: []
        )
        
        // Setup timer for automatic stop
        setupRecordingTimer(duration: durationMinutes)
        
        logFlowStep("Recording Session", step: "Event emission", category: .recording)
        CoreEvents.shared.emit(.recordingStarted(tag: tag, duration: durationMinutes))
    }
    @MainActor
    func stopRecording(isAutoStop: Bool = false) {
        guard isRecording else { return }
        
        logInfo("Stopping recording (auto: \(isAutoStop))", category: .recording)
        
        // Stop auth persistence monitoring
        AuthPersistenceManager.shared.recordingDidStop()
        
        // Cancel timers
        recordingTimer?.invalidate()
        recordingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Calculate actual duration in seconds
        let actualDurationSeconds = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // RADICAL FIX: Only process completed sessions
        // For non-sleep: only if auto-stopped (timer completed)
        // For sleep: only send completed intervals
        if !isAutoStop && currentSession?.tag != SessionTag.sleep.rawValue {
            // Manual stop for non-sleep = discard session
            let discardMessage = "Session discarded. Non-sleep recordings must complete the full duration."
            logInfo(discardMessage, category: .recording)
            
            // Clean up state
            isRecording = false
            currentSession = nil
            heartRateData.removeAll()
            recordingStartTime = nil
            elapsedTime = 0
            remainingTime = 0
            recordingProgress = 0.0
            
            // Update CoreState on MainActor
            Task { @MainActor in
                CoreEngine.shared.coreState.isRecording = false
                CoreEngine.shared.coreState.currentSession = nil
                CoreEngine.shared.coreState.elapsedTime = 0
                CoreEngine.shared.coreState.remainingTime = 0
                CoreEngine.shared.coreState.recordingProgress = 0.0
            }
            
            // Emit info event (not an error, just discarded)
            CoreEvents.shared.emit(.recordingDiscarded(reason: discardMessage))
            return
        }
        
        if heartRateData.count < 10 {
            logError("Insufficient heart rate data: \(heartRateData.count) readings", category: .recording)
            
            isRecording = false
            currentSession = nil
            
            CoreEvents.shared.emit(.recordingFailed(error: "Insufficient heart rate data"))
            return
        }
        
        // For sleep mode with manual stop - discard incomplete interval
        if !isAutoStop && currentSession?.tag == SessionTag.sleep.rawValue {
            let discardMessage = "Incomplete sleep interval discarded. Only completed intervals are saved."
            logInfo(discardMessage, category: .recording)
            
            // Clean up state but don't emit error
            isRecording = false
            currentSession = nil
            heartRateData.removeAll()
            recordingStartTime = nil
            elapsedTime = 0
            remainingTime = 0
            recordingProgress = 0.0
            
            // Update CoreState on MainActor
            Task { @MainActor in
                CoreEngine.shared.coreState.isRecording = false
                CoreEngine.shared.coreState.currentSession = nil
                CoreEngine.shared.coreState.elapsedTime = 0
                CoreEngine.shared.coreState.remainingTime = 0
                CoreEngine.shared.coreState.recordingProgress = 0.0
            }
            
            return
        }
        
        // Process the recording - only for auto-stopped sessions
        if let session = currentSession {
            // Use configured duration for completed sessions
            let finalSession = Session(
                id: session.id,
                userId: session.userId,
                tag: session.tag,
                subtag: session.subtag,
                eventId: 0,  // Always 0 per canonical
                duration: recordingDuration,  // Use configured duration for completed sessions
                rrIntervals: heartRateData,
                recordedAt: session.recordedAt
            )
            
            logInfo("Recording completed: hr_readings=\(heartRateData.count), rr_intervals=\(heartRateData.count), actual_duration=\(actualDurationSeconds) s", category: .recording)
            
            // Update state
            isRecording = false
            currentSession = nil
            
            // Notify completion
            CoreEvents.shared.emit(.recordingCompleted(session: finalSession))
            
            // Add to queue via CoreEngine
            Task { @MainActor in
                CoreEngine.shared.processCompletedSession(finalSession)
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupRecordingTimer(duration: Int) {
        let totalSeconds = duration * 60
        remainingTime = totalSeconds
        elapsedTime = 0
        recordingProgress = 0.0
        
        // Store the configured duration for reference
        recordingDuration = duration
        
        // Main recording timer - auto-stops after duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(totalSeconds), repeats: false) { [weak self] _ in
            logInfo("Recording timer expired - initiating auto-stop", category: .recording)
            Task { @MainActor in
                self?.stopRecording(isAutoStop: true)  // Mark as auto-stop
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
        guard isRecording,
              let startTime = recordingStartTime else { return }
        
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let totalDurationSeconds = recordingDuration * 60
        
        elapsedTime = elapsed
        remainingTime = max(0, totalDurationSeconds - elapsed)
        recordingProgress = min(1.0, Double(elapsed) / Double(totalDurationSeconds))
        
        // Update CoreState for UI
        CoreEngine.shared.coreState.elapsedTime = elapsed
        CoreEngine.shared.coreState.remainingTime = remainingTime
        CoreEngine.shared.coreState.recordingProgress = recordingProgress
        
        // Update current session heart rate count for UI (Canonical)
        if let session = currentSession {
            // Keep configured duration for display during recording
            currentSession = Session(
                id: session.id,
                userId: session.userId,
                tag: session.tag,
                subtag: session.subtag,
                eventId: 0,  // Always 0 per canonical
                duration: recordingDuration,  // Keep configured duration during recording
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
            // Keep configured duration for display during recording
            currentSession = Session(
                id: session.id,
                userId: session.userId,
                tag: session.tag,
                subtag: session.subtag,
                eventId: session.eventId,
                duration: recordingDuration,  // Keep configured duration during recording
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
