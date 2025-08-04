/**
 * SessionsTabView.swift
 * Clean, Direct Database Sessions Tab for HRV iOS App
 * Shows all session data in cards + debug diagnostics
 * No API complexity - Direct Supabase PostgreSQL access
 */

import SwiftUI

struct SessionsTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @StateObject private var databaseSessionManager = DatabaseSessionManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Debug & Diagnostics Card
                    DebugDiagnosticsCard(manager: databaseSessionManager)
                    
                    // Sessions Cards
                    if databaseSessionManager.sessions.isEmpty && !databaseSessionManager.isLoading {
                        EmptySessionsCard()
                    } else {
                        ForEach(databaseSessionManager.sessions) { session in
                            SessionDataCard(session: session)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sessions")
            .refreshable {
                if let userId = coreEngine.userId {
                    databaseSessionManager.refreshSessions(for: userId)
                }
            }
            .onAppear {
                if let userId = coreEngine.userId {
                    databaseSessionManager.loadSessions(for: userId)
                }
            }
            .overlay {
                if databaseSessionManager.isLoading {
                    ProgressView("Loading from database...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("Authentication Required", isPresented: .constant(databaseSessionManager.errorMessage?.contains("Authentication required") == true || databaseSessionManager.errorMessage?.contains("JWT expired") == true)) {
                Button("Go to Profile") {
                    databaseSessionManager.errorMessage = nil
                    // User can sign in again from Profile tab
                }
                Button("Cancel") {
                    databaseSessionManager.errorMessage = nil
                }
            } message: {
                Text("Your session has expired. Please sign in again from the Profile tab.")
            }
            .alert("Database Error", isPresented: .constant(databaseSessionManager.errorMessage != nil && !databaseSessionManager.errorMessage!.contains("Authentication required") && !databaseSessionManager.errorMessage!.contains("JWT expired"))) {
                Button("OK") {
                    databaseSessionManager.errorMessage = nil
                }
            } message: {
                Text(databaseSessionManager.errorMessage ?? "")
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
                    
                    ForEach(Array(statistics.processedByTag.keys.sorted(by: { $0 < $1 })), id: \.self) { tagKey in
                        let count = statistics.processedByTag[tagKey] ?? 0
                        HStack {
                            Image(systemName: tagKey == "rest" ? "heart.fill" : "moon.fill")
                                .foregroundColor(tagKey == "rest" ? .green : .purple)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: session.tag == "rest" ? "heart.fill" : "moon.fill")
                            .foregroundColor(session.tag == "rest" ? .green : .purple)
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
                    Text("Recorded: \(session.recordedAt, formatter: dateFormatter)")
                    Text("RR Intervals: \(session.rrIntervals.count)")
                    Text("Subtag: \(session.subtag)")
                    if let sleepEventId = session.sleepEventId {
                        Text("Sleep Event ID: \(sleepEventId)")
                    }
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
                    Text("Processed: \(session.processedAt, formatter: dateFormatter)")
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
}

// MARK: - Helpers
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    SessionsTabView()
        .environmentObject(CoreEngine.shared)
}
