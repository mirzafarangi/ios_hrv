import SwiftUI
import Foundation

struct RestTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var plots: [String: PlotResult] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sessionCount = 0
    @State private var currentTask: URLSessionDataTask?
    
    // Metrics to display
    private let metricsOrder = ["rmssd", "sdnn"]
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
                        Text("Rest Baseline")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("On-Demand HRV Trends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Fetch Button
                    Button(action: fetchRestBaseline) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Fetch Rest Baseline Trends")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Loading State
                    if isLoading {
                        ProgressView("Generating rest baseline plots...")
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
                            Text("\(sessionCount) rest sessions analyzed")
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
                        ForEach(metricsOrder, id: \.self) { metric in
                            if let plotResult = plots[metric] {
                                HRVPlotCard(
                                    title: displayMetrics[metric] ?? metric.uppercased(),
                                    plotResult: plotResult,
                                    tag: "rest"
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rest")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func fetchRestBaseline() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        // Cancel any existing request to prevent response mixing
        currentTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        plots = [:]
        sessionCount = 0
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/rest-baseline/\(userId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        print("🟢 REST: Fetching baseline plots from: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0  // 30 second timeout for large plot images
        
        // Add request body with metrics array
        let requestBody = ["metrics": ["rmssd", "sdnn"]]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                    print("🔍 REST: Raw response keys: \(jsonResponse?.keys.sorted() ?? [])")
                    
                    if let success = jsonResponse?["success"] as? Bool, success {
                        sessionCount = jsonResponse?["sessions_count"] as? Int ?? 0
                        print("🔍 REST: Success=\(success), Sessions=\(sessionCount)")
                        
                        if let plotsData = jsonResponse?["plots"] as? [String: [String: Any]] {
                            print("🔍 REST: Found plots data with metrics: \(plotsData.keys.sorted())")
                            for (metric, plotData) in plotsData {
                                let plotSuccess = plotData["success"] as? Bool ?? false
                                let plotDataString = plotData["plot_data"] as? String ?? ""
                                let plotError = plotData["error"] as? String
                                print("🔍 REST: \(metric) - success=\(plotSuccess), data_length=\(plotDataString.count), error=\(plotError ?? "none")")
                                
                                if plotSuccess && !plotDataString.isEmpty {
                                    
                                    if let imageData = Data(base64Encoded: plotDataString),
                                       let image = UIImage(data: imageData) {
                                        
                                        // Extract statistics from metadata
                                        var statistics: PlotStatistics?
                                        if let metadata = plotData["metadata"] as? [String: Any],
                                           let stats = metadata["statistics"] as? [String: Any] {
                                            statistics = PlotStatistics(
                                                mean: stats["mean"] as? Double ?? 0.0,
                                                std: stats["std"] as? Double ?? 0.0,
                                                min: stats["min"] as? Double ?? 0.0,
                                                max: stats["max"] as? Double ?? 0.0,
                                                p10: stats["p10"] as? Double ?? 0.0,
                                                p90: stats["p90"] as? Double ?? 0.0
                                            )
                                        }
                                        
                                        plots[metric] = PlotResult(
                                            image: image,
                                            statistics: statistics
                                        )
                                    }
                                } else {
                                    let errorMsg = plotData["error"] as? String ?? "Unknown error"
                                    print("❌ Error generating \(metric) rest baseline plot: \(errorMsg)")
                                }
                            }
                        }
                        
                        if plots.isEmpty {
                            errorMessage = "No plots were generated successfully"
                        }
                    } else {
                        let errorMsg = jsonResponse?["error"] as? String ?? "Unknown error"
                        errorMessage = "API error: \(errorMsg)"
                    }
                    
                } catch {
                    errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }
        
        currentTask = task
        task.resume()
    }
}

#Preview {
    RestTabView()
        .environmentObject(CoreEngine.shared)
}
