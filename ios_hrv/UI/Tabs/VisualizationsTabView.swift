import SwiftUI
import Foundation

struct VisualizationsTabView: View {
    @State private var selectedTag = "rest"
    @StateObject private var plotsManager = APIHRVPlotsManager()
    
    // HRV metrics in canonical schema order
    private let hrvMetrics = [
        "mean_hr", "mean_rr", "count_rr", "rmssd", 
        "sdnn", "pnn50", "cv_rr", "defa", "sd2_sd1"
    ]
    
    // Canonical tags
    private let canonicalTags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
    // Tag display configuration
    private let tagColors: [String: Color] = [
        "rest": .blue,
        "sleep": .purple,
        "experiment_paired_pre": .green,
        "experiment_paired_post": .orange,
        "experiment_duration": .red,
        "breath_workout": .cyan
    ]
    
    private let tagDisplayNames: [String: String] = [
        "rest": "Rest",
        "sleep": "Sleep",
        "experiment_paired_pre": "Pre-Experiment",
        "experiment_paired_post": "Post-Experiment",
        "experiment_duration": "Duration Test",
        "breath_workout": "Breathing"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // API Plot Statistics Summary
                    APIPlotStatisticsSummaryCard(plotsManager: plotsManager)
                    
                    // Tag Selection
                    TagSelectionCard(
                        selectedTag: $selectedTag,
                        canonicalTags: canonicalTags,
                        tagColors: tagColors,
                        tagDisplayNames: tagDisplayNames
                    )
                    
                    // Loading Progress
                    if plotsManager.isLoading {
                        VStack(spacing: 8) {
                            ProgressView(value: plotsManager.loadingProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text("Loading plots... \(Int(plotsManager.loadingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Error Message
                    if let errorMessage = plotsManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // HRV Metric Plot Cards (API-Backed)
                    ForEach(hrvMetrics, id: \.self) { metric in
                        APIHRVMetricPlotCard(
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
                await plotsManager.loadPlotsForTag(selectedTag)
            }
            .onAppear {
                Task {
                    await plotsManager.loadPlotsForTag(selectedTag)
                }
            }
            .onChange(of: selectedTag) {
                Task {
                    await plotsManager.loadPlotsForTag(selectedTag)
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
