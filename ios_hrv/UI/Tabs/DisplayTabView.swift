import SwiftUI
import Foundation

struct DisplayTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var selectedTag = "rest"
    @State private var plots: [String: PlotResult] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sessionCount = 0
    
    // Available tags for selection
    private let availableTags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
    // Metrics to display
    private let displayMetrics = [
        "rmssd": "RMSSD",
        "sdnn": "SDNN"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("HRV Trends")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Scientific Plot Visualization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Session Type:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableTags, id: \.self) { tag in
                                    TagButton(
                                        title: tag.capitalized,
                                        isSelected: selectedTag == tag,
                                        action: { selectedTag = tag }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Fetch Plots Button
                    Button(action: fetchPlots) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Fetch \(selectedTag.capitalized) Plots")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Loading State
                    if isLoading {
                        ProgressView("Generating plots...")
                            .padding()
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Session Info
                    if sessionCount > 0 {
                        VStack(spacing: 8) {
                            Text("Data Summary")
                                .font(.headline)
                            Text("\(sessionCount) \(selectedTag) sessions found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Plot Cards
                    LazyVStack(spacing: 20) {
                        ForEach(Array(displayMetrics.keys), id: \.self) { metric in
                            if let plotResult = plots[metric] {
                                HRVPlotCard(
                                    title: displayMetrics[metric] ?? metric.uppercased(),
                                    plotResult: plotResult,
                                    tag: selectedTag
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func fetchPlots() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        plots = [:]
        sessionCount = 0
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/multi-metric/\(userId)/\(selectedTag)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        print("📊 DISPLAY: Fetching plots from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = jsonResponse?["success"] as? Bool, success {
                        sessionCount = jsonResponse?["sessions_count"] as? Int ?? 0
                        
                        if let plotsData = jsonResponse?["plots"] as? [String: [String: Any]] {
                            for (metric, plotData) in plotsData {
                                if let success = plotData["success"] as? Bool, success,
                                   let plotDataString = plotData["plot_data"] as? String,
                                   !plotDataString.isEmpty {
                                    
                                    if let imageData = Data(base64Encoded: plotDataString),
                                       let image = UIImage(data: imageData) {
                                        
                                        // Extract statistics from metadata
                                        var statistics: PlotStatistics?
                                        
                                        // Debug: Print the entire plotData structure
                                        print("📊 DEBUG: Plot data for \(metric): \(plotData)")
                                        
                                        if let metadata = plotData["metadata"] as? [String: Any] {
                                            print("📊 DEBUG: Metadata found: \(metadata)")
                                            
                                            if let stats = metadata["statistics"] as? [String: Any] {
                                                print("📊 DEBUG: Statistics found: \(stats)")
                                                statistics = PlotStatistics(
                                                    mean: stats["mean"] as? Double ?? 0.0,
                                                    std: stats["std"] as? Double ?? 0.0,
                                                    min: stats["min"] as? Double ?? 0.0,
                                                    max: stats["max"] as? Double ?? 0.0,
                                                    p10: stats["p10"] as? Double ?? 0.0,
                                                    p90: stats["p90"] as? Double ?? 0.0
                                                )
                                            } else {
                                                print("📊 DEBUG: No statistics found in metadata")
                                            }
                                        } else {
                                            print("📊 DEBUG: No metadata found in plot data")
                                        }
                                        
                                        plots[metric] = PlotResult(
                                            image: image,
                                            statistics: statistics
                                        )
                                    }
                                } else {
                                    let errorMsg = plotData["error"] as? String ?? "Unknown error"
                                    print("❌ Error generating \(metric) plot: \(errorMsg)")
                                }
                            }
                        }
                        
                        print("✅ DISPLAY: Successfully loaded \(plots.count) plots")
                    } else {
                        let errorMsg = jsonResponse?["error"] as? String ?? "Unknown error"
                        errorMessage = "API Error: \(errorMsg)"
                    }
                } catch {
                    errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - Supporting Views

struct TagButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct HRVPlotCard: View {
    let title: String
    let plotResult: PlotResult
    let tag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(tag.capitalized) Sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Plot Image
            Image(uiImage: plotResult.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Statistics
            if let stats = plotResult.statistics {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        PlotDisplayStatisticItem(label: "Mean", value: String(format: "%.1f", stats.mean))
                        PlotDisplayStatisticItem(label: "Std Dev", value: String(format: "%.1f", stats.std))
                        PlotDisplayStatisticItem(label: "Min", value: String(format: "%.1f", stats.min))
                        PlotDisplayStatisticItem(label: "Max", value: String(format: "%.1f", stats.max))
                    }
                    
                    HStack {
                        Text("P10: \(String(format: "%.1f", stats.p10)) | P90: \(String(format: "%.1f", stats.p90))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct PlotDisplayStatisticItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - Data Models

struct PlotResult {
    let image: UIImage
    let statistics: PlotStatistics?
}

#Preview {
    DisplayTabView()
        .environmentObject(CoreEngine.shared)
}
