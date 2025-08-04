/**
 * SessionComponents.swift
 * Clean UI components for direct database Sessions tab
 * Shows session data cards and debug diagnostics
 */

import SwiftUI

// MARK: - Session Data Card
struct SessionDataCard: View {
    let session: DatabaseSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(session.tagEmoji) \(session.tag.capitalized)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(session.statusEmoji) \(session.status)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Session Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Duration", systemImage: "clock")
                    Spacer()
                    Text("\(session.durationMinutes) min")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Recorded", systemImage: "calendar")
                    Spacer()
                    Text(session.recordedAt, style: .date)
                        .foregroundColor(.secondary)
                }
                
                if let processedAt = session.processedAt {
                    HStack {
                        Label("Processed", systemImage: "checkmark.circle")
                        Spacer()
                        Text(processedAt, style: .time)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label("Subtag", systemImage: "tag")
                    Spacer()
                    Text(session.subtag)
                        .foregroundColor(.secondary)
                }
                
                if session.eventId > 0 {
                    HStack {
                        Label("Event Group", systemImage: "link")
                        Spacer()
                        Text("Event \(session.eventId)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)
            
            // HRV Metrics Section
            if session.hasHrvMetrics {
                Divider()
                
                Text("HRV Metrics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    if let meanHr = session.meanHr {
                        MetricView(title: "Mean HR", value: String(format: "%.1f bpm", meanHr), icon: "heart.fill")
                    }
                    
                    if let rmssd = session.rmssd {
                        MetricView(title: "RMSSD", value: String(format: "%.2f ms", rmssd), icon: "waveform.path.ecg")
                    }
                    
                    if let sdnn = session.sdnn {
                        MetricView(title: "SDNN", value: String(format: "%.2f ms", sdnn), icon: "chart.line.uptrend.xyaxis")
                    }
                    
                    if let pnn50 = session.pnn50 {
                        MetricView(title: "pNN50", value: String(format: "%.1f%%", pnn50), icon: "percent")
                    }
                    
                    if let cvRr = session.cvRr {
                        MetricView(title: "CV RR", value: String(format: "%.2f%%", cvRr), icon: "chart.bar")
                    }
                    
                    if let defa = session.defa {
                        MetricView(title: "DFA α1", value: String(format: "%.3f", defa), icon: "function")
                    }
                    
                    if let sd2Sd1 = session.sd2Sd1 {
                        MetricView(title: "SD2/SD1", value: String(format: "%.2f", sd2Sd1), icon: "circle.grid.cross")
                    }
                }
            } else {
                Divider()
                
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No HRV metrics available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Raw Data Info
            Divider()
            
            HStack {
                Label("Session ID", systemImage: "number")
                Spacer()
                Text(session.sessionId.prefix(8) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            if let rrCount = session.rrCount {
                HStack {
                    Label("RR Intervals", systemImage: "waveform")
                    Spacer()
                    Text("\(rrCount) intervals")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Metric View
struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Debug Diagnostics Card
struct DebugDiagnosticsCard: View {
    @ObservedObject var manager: DatabaseSessionManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.orange)
                Text("Debug & Diagnostics")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // Summary Stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(manager.sessions.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(manager.sessions.filter { $0.status == "completed" }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(manager.sessions.filter { $0.hasHrvMetrics }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("With Metrics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Expanded Debug Info
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pipeline Debug Log")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if manager.debugInfo.isEmpty {
                        Text("No debug information available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(manager.debugInfo.indices, id: \.self) { index in
                            Text(manager.debugInfo[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    
                    // Clear Debug Button
                    if !manager.debugInfo.isEmpty {
                        Button("Clear Debug Log") {
                            manager.clearDebugInfo()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Empty Sessions Card
struct EmptySessionsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Sessions Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Record your first HRV session in the Record tab to see data here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go to Record Tab") {
                // This would typically trigger a tab change
                // For now, it's just a placeholder
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
