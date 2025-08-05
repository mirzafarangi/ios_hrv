import SwiftUI

struct VisualizationsTabView: View {
    @State private var selectedTag = "rest"
    @StateObject private var plotsManager = DatabaseHRVPlotsManager()
    
    // HRV metrics in canonical schema order
    private let hrvMetrics = [
        "mean_hr", "mean_rr", "count_rr", "rmssd", 
        "sdnn", "pnn50", "cv_rr", "defa", "sd2_sd1"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Plot Database Summary
                    PlotStatisticsSummaryCard(plotsManager: plotsManager)
                    
                    // Tag Selection with Plot Counts
                    TagSelectionWithPlotCounts(
                        selectedTag: $selectedTag,
                        plotsManager: plotsManager
                    )
                    
                    // HRV Metric Plot Cards (DB-Backed)
                    ForEach(hrvMetrics, id: \.self) { metric in
                        DBHRVMetricPlotCard(
                            metric: metric,
                            tag: selectedTag,
                            plotsManager: plotsManager
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("HRV Analysis")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await plotsManager.loadUserPlots()
            }
            .onAppear {
                Task {
                    await plotsManager.loadUserPlots()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Get current user ID from Supabase auth service
    private func getCurrentUserId() -> String {
        return SupabaseAuthService.shared.userId ?? "unknown"
    }
}

// MARK: - Tag Selection Card

struct TagSelectionCard: View {
    @Binding var selectedTag: String
    let canonicalTags: [String]
    let tagColors: [String: Color]
    let tagDisplayNames: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select HRV Data Tag")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(canonicalTags, id: \.self) { tag in
                    Button(action: {
                        selectedTag = tag
                    }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(tagColors[tag] ?? .gray)
                                .frame(width: 12, height: 12)
                            
                            Text(tagDisplayNames[tag] ?? tag.capitalized)
                                .font(.caption)
                                .fontWeight(selectedTag == tag ? .semibold : .regular)
                                .foregroundColor(selectedTag == tag ? .primary : .secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTag == tag ? Color(.systemGray6) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTag == tag ? (tagColors[tag] ?? .gray) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}
