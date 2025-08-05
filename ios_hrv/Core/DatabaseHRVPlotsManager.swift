import Foundation
import UIKit
import Combine

// MARK: - Simplified Plot Models
struct PlotData: Codable {
    let metric: String
    let tag: String
    let plotImageBase64: String
    let statistics: PlotStatistics
    let dataPointsCount: Int
    let lastUpdated: String?
}

struct PlotStatistics: Codable {
    let mean: Double
    let std: Double
    let min: Double
    let max: Double
    let p10: Double
    let p90: Double
}

struct UserPlotsResponse: Codable {
    let success: Bool
    let plots: [String: [String: PlotData]] // [tag: [metric: plotData]]
    let totalPlots: Int
    
    enum CodingKeys: String, CodingKey {
        case success, plots
        case totalPlots = "total_plots"
    }
}

// MARK: - API-Based Plot Manager
@MainActor
class DatabaseHRVPlotsManager: ObservableObject {
    @Published var plotsByTag: [String: [String: PlotData]] = [:] // [tag: [metric: plotData]]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiBaseURL = "https://hrv-brain-api-production.up.railway.app"
    
    // MARK: - Public Methods
    
    /// Load all plots for the current authenticated user
    func loadUserPlots() async {
        guard let userId = SupabaseAuthService.shared.userId else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let url = URL(string: "\(apiBaseURL)/api/v1/plots/user/\(userId)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(UserPlotsResponse.self, from: data)
            
            await MainActor.run {
                self.plotsByTag = response.plots
                self.isLoading = false
            }
            
            print("✅ Loaded \(response.totalPlots) plots for user")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load plots: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Error loading plots: \(error)")
        }
    }
    
    /// Get a specific plot by tag and metric
    func getPlot(for tag: String, metric: String) -> PlotData? {
        return plotsByTag[tag]?[metric]
    }
    
    /// Get all plots for a specific tag
    func getPlots(for tag: String) -> [PlotData] {
        guard let tagPlots = plotsByTag[tag] else { return [] }
        return Array(tagPlots.values)
    }
    
    /// Get plot statistics summary by tag
    func getPlotStatisticsByTag() -> [String: [PlotData]] {
        return plotsByTag.mapValues { Array($0.values) }
    }
    
    /// Refresh plots for a specific tag (calls API to regenerate)
    func refreshPlotsForTag(_ tag: String) async -> Bool {
        guard let userId = SupabaseAuthService.shared.userId else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Call API to refresh plots for this tag
            let url = URL(string: "https://hrv-brain-api-production.up.railway.app/api/v1/plots/refresh/\(userId)/\(tag)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Reload plots after successful refresh
                await loadUserPlots()
                return true
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to refresh plots"
                    self.isLoading = false
                }
                return false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error refreshing plots: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Error refreshing plots: \(error)")
            return false
        }
    }
    
    /// Convert base64 string to UIImage
    func getPlotImage(from base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    /// Get formatted statistics text for a plot
    func getFormattedStatistics(for plot: PlotData) -> String {
        let stats = plot.statistics
        let unit = getUnitForMetric(plot.metric)
        
        return """
        Mean: \(String(format: "%.1f", stats.mean))\(unit)
        Std: \(String(format: "%.1f", stats.std))\(unit)
        Range: \(String(format: "%.1f", stats.min)) - \(String(format: "%.1f", stats.max))\(unit)
        P10-P90: \(String(format: "%.1f", stats.p10)) - \(String(format: "%.1f", stats.p90))\(unit)
        Data Points: \(plot.dataPointsCount)
        """
    }
    
    /// Get unit for a specific metric
    private func getUnitForMetric(_ metric: String) -> String {
        switch metric {
        case "mean_hr": return " bpm"
        case "mean_rr", "rmssd", "sdnn", "defa": return " ms"
        case "pnn50", "cv_rr": return "%"
        case "count_rr": return " beats"
        case "sd2_sd1": return ""
        default: return ""
        }
    }
}

// MARK: - Extensions
extension DatabaseHRVPlotsManager {
    /// Get display name for metric
    func getDisplayName(for metric: String) -> String {
        switch metric {
        case "mean_hr": return "Mean Heart Rate"
        case "mean_rr": return "Mean RR Interval"
        case "count_rr": return "RR Count"
        case "rmssd": return "RMSSD"
        case "sdnn": return "SDNN"
        case "pnn50": return "pNN50"
        case "cv_rr": return "CV RR"
        case "defa": return "DFA α1"
        case "sd2_sd1": return "SD2/SD1"
        default: return metric.uppercased()
        }
    }
    
    /// Get color for metric
    func getColor(for metric: String) -> String {
        switch metric {
        case "mean_hr": return "#FF6B6B"
        case "mean_rr": return "#4ECDC4"
        case "count_rr": return "#45B7D1"
        case "rmssd": return "#96CEB4"
        case "sdnn": return "#FFEAA7"
        case "pnn50": return "#DDA0DD"
        case "cv_rr": return "#98D8C8"
        case "defa": return "#F7DC6F"
        case "sd2_sd1": return "#BB8FCE"
        default: return "#666666"
        }
    }
}
