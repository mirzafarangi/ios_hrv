import SwiftUI

struct TestTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var plotImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastSessionInfo: String = "No session recorded yet"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("HRV Plot Test")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Direct RMSSD Plot Fetch Test")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Instructions:")
                            .font(.headline)
                        
                        Text("1. Record a Rest session in the Record tab")
                        Text("2. Come back here and tap 'Fetch RMSSD Plot'")
                        Text("3. This will directly call the API debug endpoint")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Session Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Session:")
                            .font(.headline)
                        Text(lastSessionInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Fetch Button
                    Button(action: fetchRMSSDPlot) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                            Text(isLoading ? "Fetching Plot..." : "Fetch RMSSD Plot")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Plot Display
                    if let plotImage = plotImage {
                        VStack(spacing: 12) {
                            Text("RMSSD Trend Plot")
                                .font(.headline)
                            
                            Image(uiImage: plotImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(15)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func fetchRMSSDPlot() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        plotImage = nil
        
        // Direct API call to debug endpoint
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/debug/plot-test/\(userId)/rest/rmssd"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        print("🧪 TEST: Fetching plot from: \(urlString)")
        
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
                        if let plotResult = jsonResponse?["plot_generation_result"] as? [String: Any],
                           let plotData = plotResult["plot_data"] as? String,
                           !plotData.isEmpty {
                            
                            // Convert base64 to image
                            if let imageData = Data(base64Encoded: plotData),
                               let image = UIImage(data: imageData) {
                                plotImage = image
                                
                                // Update session info
                                if let sessionsCount = jsonResponse?["sessions_count"] as? Int,
                                   let testData = jsonResponse?["test_data_sample"] as? [String: Any] {
                                    lastSessionInfo = "Found \(sessionsCount) session(s). Latest RMSSD: \(testData["rmssd"] ?? "N/A")"
                                }
                                
                                print("🎉 TEST: Plot loaded successfully! Image size: \(plotData.count) chars")
                            } else {
                                errorMessage = "Failed to decode plot image"
                            }
                        } else {
                            errorMessage = "Plot data is empty or missing"
                        }
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

#Preview {
    TestTabView()
        .environmentObject(CoreEngine.shared)
}
