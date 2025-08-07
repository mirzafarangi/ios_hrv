import SwiftUI

/// Main Trends tab with three-card layout
/// Clean, minimal design with centralized networking and caching
struct TrendsTabView: View {
    @StateObject private var trendsManager = TrendsManager()
    @State private var showingRefreshAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header with refresh controls
                    HeaderView(
                        trendsManager: trendsManager,
                        showingRefreshAlert: $showingRefreshAlert
                    )
                    
                    // Three trend cards
                    LazyVStack(spacing: 16) {
                        ForEach(TrendType.allCases, id: \.rawValue) { type in
                            TrendCardView(
                                type: type,
                                data: trendsManager.getData(for: type),
                                isLoading: trendsManager.isLoading
                            )
                        }
                    }
                    
                    // Footer info
                    if let lastUpdated = trendsManager.lastUpdated {
                        FooterView(lastUpdated: lastUpdated)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
            .refreshable {
                await trendsManager.fetchTrends(forceRefresh: false)
            }
        }
        .task {
            await trendsManager.loadInitialData()
        }
        .alert("Refresh Limit", isPresented: $showingRefreshAlert) {
            Button("OK") { }
        } message: {
            Text("Please wait \(trendsManager.refreshCooldownTime) seconds before refreshing again.")
        }
    }
}

/// Header with title and refresh controls
struct HeaderView: View {
    @ObservedObject var trendsManager: TrendsManager
    @Binding var showingRefreshAlert: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            
            // Title and description
            VStack(spacing: 4) {
                Text("HRV Trends Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Three trend types: Rest, Sleep Event, Sleep Baseline")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Refresh button and status
            HStack(spacing: 12) {
                
                // Refresh button
                Button(action: {
                    Task {
                        if trendsManager.canRefresh {
                            await trendsManager.fetchTrends(forceRefresh: true)
                        } else {
                            showingRefreshAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(trendsManager.canRefresh ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(trendsManager.canRefresh ? Color.blue : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
                }
                .disabled(!trendsManager.canRefresh || trendsManager.isLoading)
                
                Spacer()
                
                // Status indicator
                TrendsStatusIndicator(trendsManager: trendsManager)
            }
            
            // Error message
            if let errorMessage = trendsManager.errorMessage {
                ErrorMessageView(message: errorMessage) {
                    trendsManager.errorMessage = nil
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Status indicator showing loading, data state, etc.
struct TrendsStatusIndicator: View {
    @ObservedObject var trendsManager: TrendsManager
    
    var body: some View {
        HStack(spacing: 6) {
            if trendsManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if trendsManager.hasData {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Data loaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Error message display
struct ErrorMessageView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
            
            Button("Dismiss", action: onDismiss)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Footer with last updated info
struct FooterView: View {
    let lastUpdated: Date
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Last updated")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(lastUpdated, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

#Preview {
    TrendsTabView()
}
