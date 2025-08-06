import SwiftUI
import Foundation

struct TestTabView: View {
    @State private var plotImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var responseInfo: String = "No request made yet"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("API Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Direct Rest Baseline API Test")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Test Button
                    Button(action: testRestAPI) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isLoading ? "Testing..." : "Test Rest API")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    
                    // Response Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response Info:")
                            .font(.headline)
                        
                        Text(responseInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Plot Image
                    if let plotImage = plotImage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generated Plot:")
                                .font(.headline)
                            
                            Image(uiImage: plotImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testRestAPI() {
        isLoading = true
        errorMessage = nil
        plotImage = nil
        responseInfo = "Starting API test..."
        
        // Hardcoded test parameters
        let userId = "7015839c-4659-4b6c-821c-2906e710a2db"
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/rest-baseline/\(userId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        responseInfo = "🔗 URL: \(urlString)\n📤 Sending request..."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        // Request body
        let requestBody = ["metrics": ["rmssd"]]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        responseInfo += "\n📋 Request body: {\"metrics\": [\"rmssd\"]}"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    responseInfo += "\n❌ Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response type"
                    responseInfo += "\n❌ Invalid response type"
                    return
                }
                
                responseInfo += "\n📊 HTTP Status: \(httpResponse.statusCode)"
                
                guard let data = data else {
                    errorMessage = "No data received"
                    responseInfo += "\n❌ No data received"
                    return
                }
                
                responseInfo += "\n📦 Data size: \(data.count) bytes"
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = jsonResponse?["success"] as? Bool {
                        responseInfo += "\n✅ API Success: \(success)"
                        
                        if let sessionCount = jsonResponse?["sessions_count"] as? Int {
                            responseInfo += "\n📈 Sessions: \(sessionCount)"
                        }
                        
                        if success,
                           let plotsData = jsonResponse?["plots"] as? [String: [String: Any]],
                           let rmssdData = plotsData["rmssd"] as? [String: Any],
                           let plotSuccess = rmssdData["success"] as? Bool,
                           let plotDataString = rmssdData["plot_data"] as? String {
                            
                            responseInfo += "\n🎯 Plot Success: \(plotSuccess)"
                            responseInfo += "\n📊 Plot Data Length: \(plotDataString.count)"
                            
                            if plotSuccess && !plotDataString.isEmpty {
                                if let imageData = Data(base64Encoded: plotDataString),
                                   let image = UIImage(data: imageData) {
                                    plotImage = image
                                    responseInfo += "\n🖼️ Image decoded successfully!"
                                } else {
                                    errorMessage = "Failed to decode base64 image"
                                    responseInfo += "\n❌ Failed to decode base64 image"
                                }
                            } else {
                                errorMessage = "Plot generation failed or empty data"
                                if let plotError = rmssdData["error"] as? String {
                                    responseInfo += "\n❌ Plot error: \(plotError)"
                                }
                            }
                        } else {
                            errorMessage = "Invalid plot data structure"
                            responseInfo += "\n❌ Invalid plot data structure"
                        }
                    } else {
                        errorMessage = "API returned success=false"
                        if let apiError = jsonResponse?["error"] as? String {
                            responseInfo += "\n❌ API error: \(apiError)"
                        }
                    }
                    
                } catch {
                    errorMessage = "Failed to parse JSON: \(error.localizedDescription)"
                    responseInfo += "\n❌ JSON parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

#Preview {
    TestTabView()
}
