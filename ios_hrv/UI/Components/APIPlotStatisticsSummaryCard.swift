import SwiftUI

/// API Plot Statistics Summary Card
struct APIPlotStatisticsSummaryCard: View {
    @ObservedObject var plotsManager: APIHRVPlotsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Plot Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if plotsManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Statistics Grid
            let stats = plotsManager.getPlotStatistics()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Total Plots
                StatisticItem(
                    title: "Total Plots",
                    value: "\(stats.totalPlots)",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                // Available Tags
                StatisticItem(
                    title: "Tags with Data",
                    value: "\(stats.tagCounts.count)",
                    icon: "tag.fill",
                    color: .green
                )
            }
            
            // Tag Breakdown (if available)
            if !stats.tagCounts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plots by Tag")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(stats.tagCounts.sorted(by: { $0.key < $1.key })), id: \.key) { tag, count in
                        HStack {
                            Circle()
                                .fill(getTagColor(tag))
                                .frame(width: 8, height: 8)
                            
                            Text(getTagDisplayName(tag))
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            // API Status
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                Text("API Connection: Active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if plotsManager.errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Functions
    
    private func getTagColor(_ tag: String) -> Color {
        let tagColors: [String: Color] = [
            "rest": .blue,
            "sleep": .purple,
            "experiment_paired_pre": .green,
            "experiment_paired_post": .orange,
            "experiment_duration": .red,
            "breath_workout": .cyan
        ]
        return tagColors[tag] ?? .gray
    }
    
    private func getTagDisplayName(_ tag: String) -> String {
        let tagDisplayNames: [String: String] = [
            "rest": "Rest",
            "sleep": "Sleep",
            "experiment_paired_pre": "Pre-Experiment",
            "experiment_paired_post": "Post-Experiment",
            "experiment_duration": "Duration Test",
            "breath_workout": "Breathing"
        ]
        return tagDisplayNames[tag] ?? tag.capitalized
    }
}

/// Individual Statistic Item
struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    APIPlotStatisticsSummaryCard(plotsManager: APIHRVPlotsManager())
        .padding()
}
