import SwiftUI
import Foundation

// MARK: - API Plot Models

struct PlotResponse: Codable {
    let plotImage: String
    let metric: String
    let tag: String
    let dataPoints: Int
    let generatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case plotImage = "plot_image"
        case metric, tag
        case dataPoints = "data_points"
        case generatedAt = "generated_at"
    }
}

// MARK: - API Plot Service

@MainActor
class APIPlotService: ObservableObject {
    private let baseURL = "https://hrv-brain-api-production.up.railway.app"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchPlot(userId: String, metric: String, tag: String) async -> PlotResponse? {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/api/v1/plots/hrv-trend?user_id=\(userId)&metric=\(metric)&tag=\(tag)") else {
            errorMessage = "Invalid URL"
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                let plotResponse = try JSONDecoder().decode(PlotResponse.self, from: data)
                return plotResponse
            } else {
                // Try to decode error response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? String {
                    errorMessage = error
                } else {
                    errorMessage = "Server error: \(httpResponse.statusCode)"
                }
                return nil
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - API-Based HRV Metric Plot Card

struct APIHRVMetricPlotCard: View {
    let metric: String
    let displayName: String
    let unit: String
    let selectedTag: String
    let userId: String
    
    @StateObject private var plotService = APIPlotService()
    @State private var plotResponse: PlotResponse?
    @State private var plotImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayName) Trend Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Tag: \(selectedTag.capitalized)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Plot Content
            if plotService.isLoading {
                LoadingPlotView()
            } else if let errorMessage = plotService.errorMessage {
                ErrorPlotView(message: errorMessage) {
                    await loadPlot()
                }
            } else if let plotImage = plotImage {
                ScientificPlotView(image: plotImage, response: plotResponse)
            } else {
                EmptyPlotView(message: "No data available for \(selectedTag) sessions")
                    .onAppear {
                        Task {
                            await loadPlot()
                        }
                    }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .onChange(of: selectedTag) { _, _ in
            Task {
                await loadPlot()
            }
        }
    }
    
    private func loadPlot() async {
        plotImage = nil
        plotResponse = nil
        
        let response = await plotService.fetchPlot(userId: userId, metric: metric, tag: selectedTag)
        
        if let response = response,
           let imageData = Data(base64Encoded: response.plotImage),
           let image = UIImage(data: imageData) {
            plotResponse = response
            plotImage = image
        }
    }
}

// MARK: - Supporting Views

struct LoadingPlotView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Generating scientific plot...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorPlotView: View {
    let message: String
    let onRetry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Plot Generation Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct ScientificPlotView: View {
    let image: UIImage
    let response: PlotResponse?
    
    var body: some View {
        VStack(spacing: 12) {
            // High-quality plot image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .cornerRadius(8)
            
            // Plot metadata
            if let response = response {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Points: \(response.dataPoints)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Generated: \(formatDate(response.generatedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Scientific Analysis")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
            }
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return "Unknown"
    }
}

struct EmptyPlotView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Data Available")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - HRV Metrics Configuration

struct HRVMetricConfig {
    let key: String
    let displayName: String
    let unit: String
    let color: Color
    
    static let allMetrics = [
        HRVMetricConfig(key: "mean_hr", displayName: "Mean Heart Rate", unit: "bpm", color: .red),
        HRVMetricConfig(key: "mean_rr", displayName: "Mean RR Interval", unit: "ms", color: .blue),
        HRVMetricConfig(key: "count_rr", displayName: "RR Count", unit: "beats", color: .green),
        HRVMetricConfig(key: "rmssd", displayName: "RMSSD", unit: "ms", color: .orange),
        HRVMetricConfig(key: "sdnn", displayName: "SDNN", unit: "ms", color: .purple),
        HRVMetricConfig(key: "pnn50", displayName: "pNN50", unit: "%", color: .pink),
        HRVMetricConfig(key: "cv_rr", displayName: "CV RR", unit: "%", color: .teal),
        HRVMetricConfig(key: "defa", displayName: "DFA α1", unit: "ms", color: .yellow),
        HRVMetricConfig(key: "sd2_sd1", displayName: "SD2/SD1", unit: "ratio", color: .indigo)
    ]
}
