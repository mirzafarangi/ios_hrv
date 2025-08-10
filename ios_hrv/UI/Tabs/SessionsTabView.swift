/**
 * SessionsTabView.swift
 * Professional Expandable Accordion Sessions Tab
 * Scientific approach with scalable tag-based organization
 * Direct Supabase PostgreSQL access with comprehensive session management
 */

import SwiftUI

struct SessionsTabView: View {
    @StateObject private var databaseSessionManager = DatabaseSessionManager()
    @EnvironmentObject var coreEngine: CoreEngine
    
    @State private var totalSessionCount: Int = 0
    @State private var sessionsByTag: [String: [DatabaseSession]] = [:]
    @State private var expandedSections: Set<String> = []
    @State private var isLoadingData = false
    
    // Date formatter for session display
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoadingData {
                    ProgressView("Loading session data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Beautiful Header Band with Session Management
                            VStack(spacing: 0) {
                                // Header Band
                                HStack {
                                    // Left side - Session Management
                                    HStack(spacing: 8) {
                                        Image(systemName: "list.bullet.clipboard")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                        Text("Session Management")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Right side - Total Sessions Count
                                    HStack(spacing: 6) {
                                        Text("Total:")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(totalSessionCount)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.05),
                                            Color.blue.opacity(0.02)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color.blue.opacity(0.2)),
                                    alignment: .bottom
                                )
                                
                                // Expandable Accordion for Sessions by Tag
                                SessionAccordionView(
                                    sessionsByTag: sessionsByTag,
                                    expandedSections: $expandedSections,
                                    onDelete: handleSessionDeletion
                                )
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            // Latest Session Detail Card (if available)
                            if let latestSession = getLatestSession() {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Latest Session Details")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 20)
                                    
                                    SessionDataCard(
                                        session: latestSession,
                                        onDelete: { sessionId in
                                            handleSessionDeletion(sessionId: sessionId)
                                        }
                                    )
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await loadAllSessionData()
                    }
                }
            }
            .navigationTitle("Sessions")
            .onAppear {
                Task {
                    await loadAllSessionData()
                }
            }
            .alert("Database Error", isPresented: .constant(databaseSessionManager.errorMessage != nil)) {
                Button("OK") {
                    databaseSessionManager.errorMessage = nil
                }
            } message: {
                Text(databaseSessionManager.errorMessage ?? "")
            }
        }
    }
    
    private func loadAllSessionData() async {
        guard let userId = coreEngine.userId else { return }
        
        isLoadingData = true
        
        // Load total count and sessions by tag concurrently
        async let totalCount = databaseSessionManager.getTotalSessionCount(for: userId)
        async let sessionsByTagData = databaseSessionManager.getSessionsByTag(for: userId)
        
        let (count, sessions) = await (totalCount, sessionsByTagData)
        
        await MainActor.run {
            self.totalSessionCount = count
            self.sessionsByTag = sessions
            self.isLoadingData = false
        }
    }
    
    private func getLatestSession() -> DatabaseSession? {
        return sessionsByTag.values
            .flatMap { $0 }
            .sorted { $0.recordedAt > $1.recordedAt }
            .first
    }
    
    private func handleSessionDeletion(sessionId: String) {
        guard let userId = coreEngine.userId else {
            databaseSessionManager.debugInfo.append("Cannot delete session: No user ID available")
            return
        }
        
        Task {
            let result = await databaseSessionManager.deleteSession(sessionId: sessionId, userId: userId)
            
            await MainActor.run {
                switch result {
                case .success():
                    databaseSessionManager.debugInfo.append("Session deleted successfully: \(sessionId)")
                    // Refresh data after deletion
                    Task {
                        await loadAllSessionData()
                    }
                    
                case .failure(let error):
                    databaseSessionManager.debugInfo.append("Session deletion failed: \(error.localizedDescription)")
                    databaseSessionManager.errorMessage = "Failed to delete session: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Session Statistics Card
struct SessionStatisticsCard: View {
    let statistics: SessionStatistics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Session Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let statistics = statistics {
                // Overall Statistics
                VStack(spacing: 12) {
                    StatisticRow(label: "Raw Sessions", value: "\(statistics.rawTotal)")
                    StatisticRow(label: "Processed Sessions", value: "\(statistics.processedTotal)")
                    StatisticRow(label: "Sleep Events", value: "\(statistics.sleepEvents)")
                }
                
                Divider()
                
                // Tag-based Statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processed Sessions by Tag")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(statistics.processedByTag.keys).sorted(), id: \.self) { tagKey in
                        let count = statistics.processedByTag[tagKey] ?? 0
                        HStack {
                            Image(systemName: SessionsTabView.getTagIconHelper(tagKey))
                                .foregroundColor(SessionsTabView.getTagColorHelper(tagKey))
                            Text(tagKey.capitalized)
                            Spacer()
                            Text("\(count) sessions")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                }
            } else {
                Text("Loading statistics...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Raw Sessions Card
struct RawSessionsCard: View {
    let sessions: [RawSession]
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.orange)
                Text("Raw Sessions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if sessions.isEmpty {
                Text("No raw sessions found")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessions) { session in
                        RawSessionRow(session: session, onDelete: onDelete)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Processed Sessions Card
struct ProcessedSessionsCard: View {
    let sessions: [ProcessedSession]
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Processed Sessions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(sessions.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if sessions.isEmpty {
                Text("No processed sessions found")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessions) { session in
                        ProcessedSessionRow(session: session, onDelete: onDelete)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views
struct StatisticRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct RawSessionRow: View {
    let session: RawSession
    let onDelete: (String) -> Void
    @State private var showingDetails = false
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: SessionsTabView.getTagIconHelper(session.tag))
                            .foregroundColor(SessionsTabView.getTagColorHelper(session.tag))
                        Text(session.sessionId)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Label("Tag: \(session.tag.capitalized)", systemImage: "tag.fill")
                        Label("Duration: \(session.durationMinutes) min", systemImage: "clock.fill")
                        Label("RR Count: \(session.rrCount)", systemImage: "waveform.path.ecg")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    onDelete(session.sessionId)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recorded: \(formatDate(session.recordedAt))")
                    Text("RR Intervals: \(session.rrIntervals.count)")
                    Text("Subtag: \(session.subtag)")
                    Text("Event ID: \(session.eventId)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingDetails.toggle()
            }
        }
    }
}

struct ProcessedSessionRow: View {
    let session: ProcessedSession
    let onDelete: (String) -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(session.id)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Label("Status: \(session.status)", systemImage: "info.circle.fill")
                        Label("RMSSD: \(session.hrvMetrics.rmssd.map { String(format: "%.2f", $0) } ?? "N/A")", systemImage: "heart.fill")
                        Label("SDNN: \(session.hrvMetrics.sdnn.map { String(format: "%.2f", $0) } ?? "N/A")", systemImage: "waveform.path.ecg")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    onDelete(session.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Processed: \(formatDate(session.processedAt ?? Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 4) {
                        ForEach(session.hrvMetrics.allMetrics, id: \.0) { metric in
                            HStack {
                                Text(metric.0)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(metric.1)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingDetails.toggle()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func getTagIcon(_ tag: String) -> String {
        switch tag {
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
    
    static func getTagColor(_ tag: String) -> Color {
        switch tag {
        case "wake_check":
            return .orange
        case "pre_sleep":
            return .indigo
        case "sleep":
            return .purple
        case "experiment":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Tag Helper Functions
extension SessionsTabView {
    static func getTagIconHelper(_ tag: String) -> String {
        switch tag {
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
    
    static func getTagColorHelper(_ tag: String) -> Color {
        switch tag {
        case "wake_check":
            return .orange
        case "pre_sleep":
            return .indigo
        case "sleep":
            return .purple
        case "experiment":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Preview
#Preview {
    SessionsTabView()
        .environmentObject(CoreEngine.shared)
}
