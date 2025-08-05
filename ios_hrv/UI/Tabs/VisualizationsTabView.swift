import SwiftUI

struct VisualizationsTabView: View {
    @State private var selectedTag = "rest"
    
    // Canonical tags from schema.md
    private let canonicalTags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
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
        "experiment_duration": "Experiment Duration",
        "breath_workout": "Breath Workout"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Tag Selection Card
                    TagSelectionCard(
                        selectedTag: $selectedTag,
                        canonicalTags: canonicalTags,
                        tagColors: tagColors,
                        tagDisplayNames: tagDisplayNames
                    )
                    
                    // API-Generated HRV Metric Trend Cards (All 9 metrics in schema order)
                    ForEach(HRVMetricConfig.allMetrics, id: \.key) { metricConfig in
                        APIHRVMetricPlotCard(
                            metric: metricConfig.key,
                            displayName: metricConfig.displayName,
                            unit: metricConfig.unit,
                            selectedTag: selectedTag,
                            userId: getCurrentUserId()
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("HRV Analysis")
        }
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentUserId() -> String {
        // Get current user ID from Supabase auth
        // This should be implemented to get the actual authenticated user ID
        return "oMeXbIPwTXUU1WRkrLU0mtQOU9r1" // Placeholder - replace with actual auth service
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
