/**
 * ConfigCard.swift
 * Recording configuration UI component for HRV iOS App
 * Tag selection and duration settings
 */

import SwiftUI

struct ConfigCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Image(systemName: "gear.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Recording Configuration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Tag Selection (Dropdown)
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Menu {
                    ForEach(SessionTag.allCases, id: \.self) { tag in
                        Button(action: {
                            let duration = tag.defaultDurationMinutes
                            coreEngine.updateRecordingConfiguration(tag: tag, duration: duration)
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
                
                // Tag Description
                Text(coreEngine.coreState.selectedTag.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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
                .accentColor(.blue)
                
                // Duration hint for sleep mode
                if coreEngine.coreState.selectedTag.isAutoRecordingMode {
                    Text("Sleep mode records continuous intervals until you stop")
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
    }
    
    // MARK: - Computed Properties
    private var configurationSummary: String {
        let tag = coreEngine.coreState.selectedTag
        let duration = coreEngine.coreState.selectedDuration
        
        return "\(tag.description) for \(duration) minute\(duration == 1 ? "" : "s")"
    }
}

#Preview {
    VStack(spacing: 16) {
        ConfigCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.selectedTag = .rest
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
