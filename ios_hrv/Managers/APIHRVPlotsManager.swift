import SwiftUI
import Foundation
import Combine

/// API-based HRV Plots Manager using individual working endpoints
@MainActor
class APIHRVPlotsManager: ObservableObject {
    @Published var plots: [String: [String: UIImage]] = [:] // [tag: [metric: image]]
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    private let session = URLSession.shared
    
    // HRV metrics in canonical schema order
    private let hrvMetrics = [
        "mean_hr", "mean_rr", "count_rr", "rmssd", 
        "sdnn", "pnn50", "cv_rr", "defa", "sd2_sd1"
    ]
    
    // Canonical tags
    private let canonicalTags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
    /// Load all plots for the current user and selected tag
    func loadPlotsForTag(_ tag: String) async {
        guard let userId = getCurrentUserId() else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        loadingProgress = 0.0
        errorMessage = nil
        
        print("🔄 Loading plots for tag: \(tag), user: \(userId)")
        
        // Initialize plots dictionary for this tag if needed
        if plots[tag] == nil {
            plots[tag] = [:]
        }
        
        let totalMetrics = Double(hrvMetrics.count)
        var completedMetrics = 0.0
        
        // Load each metric individually using working API endpoints
        for metric in hrvMetrics {
            if let plotImage = await loadPlotForMetric(metric, tag: tag, userId: userId) {
                plots[tag]?[metric] = plotImage
                print("✅ Loaded plot for \(metric): \(tag)")
            } else {
                print("❌ Failed to load plot for \(metric): \(tag)")
            }
            
            completedMetrics += 1.0
            loadingProgress = completedMetrics / totalMetrics
        }
        
        isLoading = false
        print("🎯 Completed loading plots for tag: \(tag)")
    }
    
    /// Load individual plot for a specific metric using working API endpoint
    private func loadPlotForMetric(_ metric: String, tag: String, userId: String) async -> UIImage? {
        let urlString = "\(baseURL)/api/v1/debug/plot-test/\(userId)/\(tag)/\(metric)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }
        
        do {
            print("📡 Fetching plot: \(metric) for \(tag)...")
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ HTTP Error for \(metric): \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            
            // Parse JSON response
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = jsonObject["success"] as? Bool,
                  success == true,
                  let plotDataBase64 = jsonObject["plot_data"] as? String,
                  !plotDataBase64.isEmpty else {
                print("❌ Invalid JSON response for \(metric)")
                return nil
            }
            
            // Convert base64 to UIImage
            guard let imageData = Data(base64Encoded: plotDataBase64),
                  let image = UIImage(data: imageData) else {
                print("❌ Failed to decode base64 image for \(metric)")
                return nil
            }
            
            print("✅ Successfully loaded plot for \(metric): \(imageData.count) bytes")
            return image
            
        } catch {
            print("❌ Network error for \(metric): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get plot image for specific metric and tag
    func getPlotImage(for metric: String, tag: String) -> UIImage? {
        return plots[tag]?[metric]
    }
    
    /// Check if plot exists for metric and tag
    func hasPlot(for metric: String, tag: String) -> Bool {
        return plots[tag]?[metric] != nil
    }
    
    /// Get loading status for specific tag
    func isLoadingTag(_ tag: String) -> Bool {
        return isLoading
    }
    
    /// Clear all plots (useful for refresh)
    func clearPlots() {
        plots.removeAll()
        errorMessage = nil
        loadingProgress = 0.0
    }
    
    /// Get current user ID from authentication service
    private func getCurrentUserId() -> String? {
        return SupabaseAuthService.shared.userId
    }
    
    /// Get plot statistics for display
    func getPlotStatistics() -> (totalPlots: Int, tagCounts: [String: Int]) {
        var totalPlots = 0
        var tagCounts: [String: Int] = [:]
        
        for (tag, tagPlots) in plots {
            let count = tagPlots.count
            tagCounts[tag] = count
            totalPlots += count
        }
        
        return (totalPlots: totalPlots, tagCounts: tagCounts)
    }
}

// MARK: - Plot Display Components

/// Individual HRV Metric Plot Card using API data
struct APIHRVMetricPlotCard: View {
    let metric: String
    let tag: String
    @ObservedObject var plotsManager: APIHRVPlotsManager
    
    // Metric display configuration
    private let metricDisplayNames: [String: String] = [
        "mean_hr": "Mean Heart Rate",
        "mean_rr": "Mean RR Interval", 
        "count_rr": "RR Count",
        "rmssd": "RMSSD",
        "sdnn": "SDNN",
        "pnn50": "pNN50",
        "cv_rr": "CV RR",
        "defa": "DFA α1",
        "sd2_sd1": "SD2/SD1"
    ]
    
    private let metricUnits: [String: String] = [
        "mean_hr": "bpm",
        "mean_rr": "ms",
        "count_rr": "beats",
        "rmssd": "ms", 
        "sdnn": "ms",
        "pnn50": "%",
        "cv_rr": "%",
        "defa": "",
        "sd2_sd1": "ratio"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metricDisplayNames[metric] ?? metric.uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let unit = metricUnits[metric], !unit.isEmpty {
                        Text("Unit: \(unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Loading indicator or status
                if plotsManager.isLoadingTag(tag) {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if plotsManager.hasPlot(for: metric, tag: tag) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            // Plot Display
            if let plotImage = plotsManager.getPlotImage(for: metric, tag: tag) {
                Image(uiImage: plotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else if plotsManager.isLoadingTag(tag) {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            ProgressView()
                            Text("Generating plot...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    )
            } else {
                // No data placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No plot available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
