import SwiftUI
import UIKit

// MARK: - DB-Backed HRV Plot Card
struct DBHRVMetricPlotCard: View {
    let metric: String
    let tag: String
    @ObservedObject var plotsManager: DatabaseHRVPlotsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plotsManager.getDisplayName(for: metric))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Tag: \(tag.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    Task {
                        await plotsManager.refreshPlotsForTag(tag)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .disabled(plotsManager.isLoading)
            }
            
            // Plot content
            if let plot = plotsManager.getPlot(for: tag, metric: metric) {
                // Plot image
                if let plotImage = plotsManager.getPlotImage(from: plot.plotImageBase64) {
                    Image(uiImage: plotImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                } else {
                    PlotErrorView(message: "Failed to load plot image")
                }
                
                // Statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scientific Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(plotsManager.getFormattedStatistics(for: plot))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                    
                    if let lastUpdated = plot.lastUpdated {
                        Text("Last Updated: \(lastUpdated)")
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
                .padding(.vertical, 8)
                
            } else if plotsManager.isLoading {
                PlotLoadingView()
            } else {
                PlotEmptyView(
                    message: "No plot data available",
                    suggestion: "Record some \(tag) sessions to generate plots"
                )
            }
            
            // Error message
            if let errorMessage = plotsManager.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Plot State Views
struct PlotLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading plot from database...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

struct PlotEmptyView: View {
    let message: String
    let suggestion: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text(suggestion)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

struct PlotErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

// MARK: - Plot Statistics Summary Card
struct PlotStatisticsSummaryCard: View {
    @ObservedObject var plotsManager: DatabaseHRVPlotsManager
    
    private var sortedTags: [String] {
        Array(plotsManager.getPlotStatisticsByTag().keys).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plot Database Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            let plotsByTag = plotsManager.getPlotStatisticsByTag()
            
            if plotsByTag.isEmpty {
                Text("No plots available in database")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedTags, id: \.self) { tag in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tag.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(plotsManager.plotsByTag[tag]?.count ?? 0) plots available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let plots = plotsManager.plotsByTag[tag], let firstPlot = plots.values.first, let lastUpdated = firstPlot.lastUpdated {
                            Text("Updated: \(lastUpdated)")
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Total plots count
            HStack {
                Text("Total Plots:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(plotsManager.plotsByTag.values.map { $0.count }.reduce(0, +))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3)),
                alignment: .top
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Tag Selection with Plot Counts
struct TagSelectionWithPlotCounts: View {
    @Binding var selectedTag: String
    @ObservedObject var plotsManager: DatabaseHRVPlotsManager
    
    let tags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select HRV Data Tag")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(tags, id: \.self) { tag in
                    TagButtonWithCount(
                        tag: tag,
                        isSelected: selectedTag == tag,
                        plotCount: plotsManager.getPlots(for: tag).count
                    ) {
                        selectedTag = tag
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TagButtonWithCount: View {
    let tag: String
    let isSelected: Bool
    let plotCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(plotCount) plots")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var displayName: String {
        switch tag {
        case "rest": return "Rest"
        case "sleep": return "Sleep"
        case "experiment_paired_pre": return "Pre-Experiment"
        case "experiment_paired_post": return "Post-Experiment"
        case "experiment_duration": return "Experiment Duration"
        case "breath_workout": return "Breath Workout"
        default: return tag.capitalized
        }
    }
    
    private var color: Color {
        switch tag {
        case "rest": return .blue
        case "sleep": return .purple
        case "experiment_paired_pre": return .green
        case "experiment_paired_post": return .orange
        case "experiment_duration": return .red
        case "breath_workout": return .cyan
        default: return .gray
        }
    }
}
