/**
 * ConfigCard.swift
 * Recording configuration UI component for HRV iOS App
 * Canonical tag selection and duration settings (db_schema.sql compliant)
 */

import SwiftUI

struct ConfigCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var experimentProtocolName: String = ""
    @State private var isPairedMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Image(systemName: coreEngine.coreState.isRecording ? "lock.circle.fill" : "gear.circle.fill")
                    .foregroundColor(coreEngine.coreState.isRecording ? .orange : .blue)
                    .font(.title2)
                
                Text("Recording Configuration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if coreEngine.coreState.isRecording {
                    Text("Locked")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Tag Selection (Canonical - 4 tags only)
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Menu {
                    // Canonical tags: wake_check, pre_sleep, sleep, experiment
                    ForEach(SessionTag.allCases, id: \.self) { tag in
                        Button(action: {
                            let duration = tag.defaultDurationMinutes
                            coreEngine.updateRecordingConfiguration(
                                tag: tag,
                                duration: duration,
                                isPaired: isPairedMode,
                                protocolName: experimentProtocolName
                            )
                        }) {
                            HStack {
                                Image(systemName: tag.icon)
                                Text(tag.displayName)
                                Spacer()
                                if coreEngine.coreState.selectedTag == tag {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: coreEngine.coreState.selectedTag.icon)
                            .foregroundColor(.blue)
                        
                        Text(coreEngine.coreState.selectedTag.displayName)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(coreEngine.coreState.isRecording)
                
                // Tag Description
                Text(coreEngine.coreState.selectedTag.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Additional Options for specific tags
            if coreEngine.coreState.selectedTag == .wakeCheck || coreEngine.coreState.selectedTag == .preSleep {
                // Paired mode toggle for wake_check and pre_sleep
                Toggle(isOn: $isPairedMode) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(coreEngine.coreState.isRecording ? .gray : .blue)
                        Text("Paired Mode")
                            .font(.subheadline)
                    }
                }
                .disabled(coreEngine.coreState.isRecording)
                .onChange(of: isPairedMode) { _, newValue in
                    coreEngine.updateRecordingConfiguration(
                        tag: coreEngine.coreState.selectedTag,
                        duration: coreEngine.coreState.selectedDuration,
                        isPaired: newValue,
                        protocolName: experimentProtocolName
                    )
                }
                
                if isPairedMode {
                    Text(coreEngine.coreState.selectedTag == .wakeCheck ? 
                         "Will generate subtag: wake_check_paired_day_pre" :
                         "Will generate subtag: pre_sleep_paired_day_post")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if coreEngine.coreState.selectedTag == .experiment {
                // Protocol name input for experiment tag
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocol Name (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter protocol name", text: $experimentProtocolName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(coreEngine.coreState.isRecording)
                        .onChange(of: experimentProtocolName) { _, newValue in
                            coreEngine.updateRecordingConfiguration(
                                tag: coreEngine.coreState.selectedTag,
                                duration: coreEngine.coreState.selectedDuration,
                                isPaired: isPairedMode,
                                protocolName: newValue
                            )
                        }
                    
                    Text(experimentProtocolName.isEmpty ?
                         "Will generate subtag: experiment_single" :
                         "Will generate subtag: experiment_protocol_\(experimentProtocolName.lowercased().replacingOccurrences(of: " ", with: "_"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Duration Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(coreEngine.coreState.selectedDuration) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    if coreEngine.coreState.selectedTag.isAutoRecordingMode {
                        Text("(per interval)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Slider(
                    value: Binding(
                        get: { Double(coreEngine.coreState.selectedDuration) },
                        set: { newValue in
                            let duration = Int(newValue)
                            coreEngine.updateRecordingConfiguration(
                                tag: coreEngine.coreState.selectedTag,
                                duration: duration
                            )
                        }
                    ),
                    in: Double(coreEngine.coreState.selectedTag.minDurationMinutes)...Double(coreEngine.coreState.selectedTag.maxDurationMinutes),
                    step: 1
                ) {
                    Text("Duration")
                } minimumValueLabel: {
                    Text("\(coreEngine.coreState.selectedTag.minDurationMinutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("\(coreEngine.coreState.selectedTag.maxDurationMinutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(coreEngine.coreState.isRecording ? .gray : .blue)
                .disabled(coreEngine.coreState.isRecording)
                
                // Duration hint for sleep mode
                if coreEngine.coreState.selectedTag == .sleep {
                    Text("Sleep mode records continuous intervals until you stop. Each interval will be tagged as sleep_interval_1, sleep_interval_2, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            // Configuration Summary
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(configurationSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            // Overlay to show recording is active
            coreEngine.coreState.isRecording ?
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.05))
                .allowsHitTesting(false)
            : nil
        )
    }
    
    // MARK: - Computed Properties
    private var configurationSummary: String {
        let tag = coreEngine.coreState.selectedTag
        let duration = coreEngine.coreState.selectedDuration
        let subtag = tag.generateSubtag(
            isPaired: isPairedMode,
            intervalNumber: tag == .sleep ? 1 : nil,
            protocolName: experimentProtocolName.isEmpty ? nil : experimentProtocolName
        )
        
        return "\(tag.description) for \(duration) minute\(duration == 1 ? "" : "s") (\(subtag))"
    }
}

#Preview {
    VStack(spacing: 16) {
        ConfigCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.selectedTag = .wakeCheck
                engine.coreState.selectedDuration = 5
                return engine
            }())
        
        ConfigCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.selectedTag = .sleep
                engine.coreState.selectedDuration = 15
                return engine
            }())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
