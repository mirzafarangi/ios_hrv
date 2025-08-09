/**
 * RecordingCard.swift
 * Recording control UI component for HRV iOS App
 * Start/stop recording with progress and status display
 */

import SwiftUI

struct RecordingCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Image(systemName: "record.circle.fill")
                    .foregroundColor(coreEngine.coreState.isRecording ? .red : .gray)
                    .font(.title2)
                    .scaleEffect(coreEngine.coreState.isRecording && pulse ? 1.18 : 1.0)
                    .animation(.easeInOut(duration: beatDuration()).repeatForever(autoreverses: true), value: pulse)

                Text("Recording Session")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Recording Status
            if coreEngine.coreState.isRecording {
                recordingStatusView
            } else {
                readyToRecordView
            }
            
            // Recording Button
            HStack {
                Spacer()
                
                Button(action: {
                    if coreEngine.coreState.isRecording {
                        // Handle stop based on recording mode
                        if coreEngine.coreState.isInAutoRecordingMode {
                            coreEngine.stopAutoRecording()
                        } else {
                            coreEngine.stopRecording()
                        }
                    } else {
                        // Start recording with current mode
                        coreEngine.startRecordingWithCurrentMode()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: recordingButtonIcon)
                            .font(.title3)
                        
                        Text(recordingButtonText)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(recordingButtonColor)
                    .cornerRadius(12)
                }
                .disabled(!canToggleRecording)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Recording Status View
    @ViewBuilder
    private var recordingStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Current Session Info
            if let session = coreEngine.coreState.currentSession {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: getTagIcon(session.tag))
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        
                        Text(getTagDisplayName(session.tag))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(session.rrIntervals.count) readings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Sleep Event Information (Auto-Recording Mode)
                    if coreEngine.coreState.isInAutoRecordingMode {
                        HStack {
                            Image(systemName: "moon.circle.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                            
                            Text("Sleep Recording")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Interval \(coreEngine.coreState.currentSleepIntervalNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Sleep Interval Tag Display
                    if !session.subtag.isEmpty && session.isSleepInterval {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                            
                            Text(session.subtag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Progress Bar with Timer
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Timer display
                    Text(formatTime(coreEngine.coreState.remainingTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: coreEngine.coreState.recordingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 0.8)
                
                // Elapsed time display
                HStack {
                    Text("Elapsed: \(formatTime(coreEngine.coreState.elapsedTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(coreEngine.coreState.recordingProgress * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            
            // Live HR/RR Metrics (single "Live" terminology)
            if coreEngine.coreState.currentHeartRate > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .scaleEffect(pulse ? 1.22 : 1.0)
                        .animation(.easeInOut(duration: beatDuration()).repeatForever(autoreverses: true), value: pulse)

                    Text("Live HR:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(coreEngine.coreState.currentHeartRate) BPM")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("•")
                        .foregroundColor(.secondary)

                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .scaleEffect(pulse ? 1.22 : 1.0)
                        .animation(.easeInOut(duration: beatDuration()).repeatForever(autoreverses: true), value: pulse)

                    Text("Live RR:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(latestRRText())
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let count = coreEngine.coreState.currentSession?.rrIntervals.count {
                        Text("(") + Text("\(count)").bold() + Text(" readings)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .onChange(of: coreEngine.coreState.currentHeartRate) {
            // retrigger animation when HR changes
            if coreEngine.coreState.isRecording { pulse.toggle() }
        }
        .onAppear {
            if coreEngine.coreState.isRecording { pulse = true }
        }
    }
    
    // MARK: - Ready to Record View
    @ViewBuilder
    private var readyToRecordView: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Recording Preview
            HStack {
                Image(systemName: coreEngine.coreState.selectedTag.icon)
                    .foregroundColor(.blue)
                    .font(.subheadline)
                
                Text("Ready to record \(coreEngine.coreState.selectedTag.displayName.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Duration Preview
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                
                Text("Duration: \(coreEngine.coreState.selectedDuration) minute\(coreEngine.coreState.selectedDuration == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Requirements Check
            if !coreEngine.coreState.canStartRecording {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(recordingRequirementMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canToggleRecording: Bool {
        if coreEngine.coreState.isRecording {
            return true // Can always stop recording
        } else {
            return coreEngine.coreState.canStartRecording
        }
    }
    
    private var recordingButtonText: String {
        if coreEngine.coreState.isRecording {
            if coreEngine.coreState.isInAutoRecordingMode {
                return "Stop Auto-Recording"
            } else {
                return "Stop Recording"
            }
        } else {
            if coreEngine.coreState.selectedTag.isAutoRecordingMode {
                return "Start Auto-Recording Sleep Event"
            } else {
                return "Start Recording"
            }
        }
    }
    
    private var recordingButtonIcon: String {
        if coreEngine.coreState.isRecording {
            return "stop.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
    
    private var recordingButtonColor: Color {
        if coreEngine.coreState.isRecording {
            return .red
        } else if coreEngine.coreState.canStartRecording {
            return .green
        } else {
            return .gray
        }
    }
    
    private var recordingRequirementMessage: String {
        if !coreEngine.coreState.sensorConnectionState.isConnected {
            return "Connect sensor to start recording"
        } else {
            return "Ready to record"
        }
    }
    
    // MARK: - Helper Functions
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func latestRRText() -> String {
        if let rr = coreEngine.coreState.currentSession?.rrIntervals.last {
            return String(format: "%.0f ms", rr)
        }
        return "-- ms"
    }
    
    private func beatDuration() -> Double {
        let hr = max(30, min(200, coreEngine.coreState.currentHeartRate))
        return hr > 0 ? (60.0 / Double(hr)) : 1.0
    }
    
    // MARK: - Helper Functions
    
    private func getTagIcon(_ tag: String) -> String {
        switch tag.lowercased() {
        case "wake_check":
            return "sun.max.fill"
        case "pre_sleep":
            return "moon.stars.fill"
        case "sleep":
            return "moon.fill"
        case "experiment":
            return "flask.fill"
        default:
            return "heart.fill"
        }
    }
    
    private func getTagDisplayName(_ tag: String) -> String {
        switch tag.lowercased() {
        case "wake_check":
            return "Wake Check"
        case "pre_sleep":
            return "Pre-Sleep"
        case "sleep":
            return "Sleep"
        case "experiment":
            return "Experiment"
        default:
            return tag.capitalized
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Ready to record state
        RecordingCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.sensorConnectionState = .connected
                engine.coreState.isRecording = false
                engine.coreState.selectedTag = .wakeCheck
                engine.coreState.selectedDuration = 5
                return engine
            }())
        
        // Recording state
        RecordingCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.sensorConnectionState = .connected
                engine.coreState.isRecording = true
                engine.coreState.currentHeartRate = 72
                engine.coreState.currentSession = Session(
                    id: "test-session-2",
                    userId: "test",
                    tag: "wake_check",
                    subtag: "",
                    eventId: 0,
                    duration: 5,
                    rrIntervals: [800, 820, 810, 830]
                )
                return engine
            }())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
