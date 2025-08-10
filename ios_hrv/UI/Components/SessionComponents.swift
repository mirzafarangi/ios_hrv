/**
 * SessionComponents.swift
 * Clean UI components for direct database Sessions tab
 * Shows session data cards and debug diagnostics
 */

import SwiftUI

// MARK: - HRV Metric Category
enum HRVMetricCategory {
    case timeDomain
    case frequencyNonlinear
    case general
    
    var color: Color {
        switch self {
        case .timeDomain:
            return .blue
        case .frequencyNonlinear:
            return .purple
        case .general:
            return .green
        }
    }
}

// MARK: - HRV Metric Row Component
struct HRVMetricRow: View {
    let label: String
    let value: String
    let unit: String
    let category: HRVMetricCategory
    
    var body: some View {
        HStack(spacing: 0) {
            // Category indicator with consistent color
            Circle()
                .fill(category.color.opacity(0.6))
                .frame(width: 6, height: 6)
                .padding(.trailing, 10)
            
            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            // Value and unit
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Session Data Card
struct SessionDataCard: View {
    let session: DatabaseSession
    let onDelete: ((String) -> Void)?
    
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    init(session: DatabaseSession, onDelete: ((String) -> Void)? = nil) {
        self.session = session
        self.onDelete = onDelete
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(session.tagEmoji) \(session.tag.capitalized)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isDeleting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Deleting...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text("\(session.statusEmoji) \(session.status)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                        
                        if onDelete != nil {
                            Button(action: {
                                deleteSession()
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
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
            
            // HRV Metrics Section - Academic Scientific Design
            if session.hasHrvMetrics {
                Divider()
                    .padding(.vertical, 8)
                
                // Scientific Header
                HStack {
                    Text("HRV Metrics")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Analysis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
                
                // Metrics in Academic Layout - Primary Metrics
                VStack(spacing: 0) {
                    // Time Domain Header
                    HStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 3, height: 12)
                        Text("TIME DOMAIN")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue.opacity(0.8))
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.bottom, 10)
                    
                    // Primary Time Domain Metrics (RMSSD, SDNN, pNN50)
                    VStack(spacing: 10) {
                        if let rmssd = session.rmssd {
                            HRVMetricRow(
                                label: "RMSSD",
                                value: String(format: "%.2f", rmssd),
                                unit: "ms",
                                category: .timeDomain
                            )
                        }
                        
                        if let sdnn = session.sdnn {
                            HRVMetricRow(
                                label: "SDNN",
                                value: String(format: "%.2f", sdnn),
                                unit: "ms",
                                category: .timeDomain
                            )
                        }
                        
                        if let pnn50 = session.pnn50 {
                            HRVMetricRow(
                                label: "pNN50",
                                value: String(format: "%.1f", pnn50),
                                unit: "%",
                                category: .timeDomain
                            )
                        }
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1)
                        .padding(.vertical, 12)
                    
                    // Frequency & Nonlinear Header
                    HStack {
                        Rectangle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 3, height: 12)
                        Text("FREQUENCY & NONLINEAR")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.purple.opacity(0.8))
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.bottom, 10)
                    
                    // Frequency & Nonlinear Metrics
                    VStack(spacing: 10) {
                        if let defa = session.defa {
                            HRVMetricRow(
                                label: "DFA α1",
                                value: String(format: "%.3f", defa),
                                unit: "",
                                category: .frequencyNonlinear
                            )
                        }
                        
                        if let sd2Sd1 = session.sd2Sd1 {
                            HRVMetricRow(
                                label: "SD2/SD1",
                                value: String(format: "%.2f", sd2Sd1),
                                unit: "",
                                category: .frequencyNonlinear
                            )
                        }
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1)
                        .padding(.vertical, 12)
                    
                    // General Metrics Header
                    HStack {
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 3, height: 12)
                        Text("GENERAL")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.bottom, 10)
                    
                    // General Metrics
                    VStack(spacing: 10) {
                        if let meanHr = session.meanHr {
                            HRVMetricRow(
                                label: "Mean HR",
                                value: String(format: "%.1f", meanHr),
                                unit: "bpm",
                                category: .general
                            )
                        }
                        
                        if let rrCount = session.rrCount {
                            HRVMetricRow(
                                label: "RR Count",
                                value: "\(rrCount)",
                                unit: "",
                                category: .general
                            )
                        }
                        
                        if let cvRr = session.cvRr {
                            HRVMetricRow(
                                label: "CV-RR",
                                value: String(format: "%.2f", cvRr),
                                unit: "%",
                                category: .general
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            } else {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No HRV metrics available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Insufficient RR intervals for analysis")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
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
        .alert("Delete Failed", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }
    
    private func deleteSession() {
        guard let onDelete = onDelete else { return }
        
        isDeleting = true
        deleteError = nil
        
        // Call the delete handler
        onDelete(session.sessionId)
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

// MARK: - Session Diagnostics Card
struct SessionDiagnosticsCard: View {
    let totalCount: Int
    let debugInfo: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Database Diagnostics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                Text("Total Sessions:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(totalCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
            
            if !debugInfo.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                Text("Recent Operations")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(debugInfo.suffix(3).enumerated()), id: \.offset) { index, info in
                            Text(info)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Session Accordion View
struct SessionAccordionView: View {
    let sessionsByTag: [String: [DatabaseSession]]
    @Binding var expandedSections: Set<String>
    let onDelete: (String) -> Void
    
    var sortedTags: [String] {
        sessionsByTag.keys.sorted()
    }
    
    var body: some View {
        if sessionsByTag.isEmpty {
            EmptySessionsCard()
        } else {
            VStack(spacing: 12) {
                ForEach(sortedTags, id: \.self) { tag in
                    VStack(spacing: 0) {
                        // Section Header
                        SessionTagHeader(
                            tag: tag,
                            sessionCount: sessionsByTag[tag]?.count ?? 0,
                            isExpanded: expandedSections.contains(tag),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if expandedSections.contains(tag) {
                                        expandedSections.remove(tag)
                                    } else {
                                        expandedSections.insert(tag)
                                    }
                                }
                            }
                        )
                        
                        // Expanded Content with List for swipe actions
                        if expandedSections.contains(tag) {
                            List {
                                ForEach(sessionsByTag[tag] ?? []) { session in
                                    SessionRowView(
                                        session: session,
                                        onDelete: onDelete
                                    )
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: CGFloat((sessionsByTag[tag]?.count ?? 0) * 60))
                            .clipped()
                            .padding(.top, 4)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                }
            }
        }
    }
}

// MARK: - Session Tag Header
struct SessionTagHeader: View {
    let tag: String
    let sessionCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private var tagDisplayName: String {
        switch tag {
        case "sleep": return "Sleep"
        case "wake_check": return "Wake Check"
        case "pre_sleep": return "Pre-Sleep"
        case "experiment": return "Experiment"
        default: return tag.capitalized
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(tagDisplayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(sessionCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: DatabaseSession
    let onDelete: (String) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.recordedAt))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    // Tag and Subtag
                    Text("\(session.tag)/\(session.subtag)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    // Event ID if present
                    if session.eventId > 0 {
                        Text("Event #\(session.eventId)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.durationMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(session.status.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(session.status == "completed" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    
                    if let meanHr = session.meanHr {
                        Text("\(Int(meanHr)) BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if session.hasHrvMetrics {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                onDelete(session.sessionId)
            }
        }
    }
}
