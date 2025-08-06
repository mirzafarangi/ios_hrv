import SwiftUI
import Foundation

struct SleepTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var availableEventIds: [Int] = []
    @State private var selectedEventId: Int?
    @State private var eventPlots: [String: PlotResult] = [:]
    @State private var baselinePlots: [String: PlotResult] = [:]
    @State private var isLoadingEvents = false
    @State private var isLoadingEventPlots = false
    @State private var isLoadingBaselinePlots = false
    @State private var errorMessage: String?
    @State private var eventSessionCount = 0
    @State private var baselineEventsCount = 0
    
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
                        Text("Sleep Analysis")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Event-Based HRV Trends")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Load Events Button
                    Button(action: loadSleepEvents) {
                        HStack {
                            Image(systemName: "moon.fill")
                            Text("Load Sleep Events")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingEvents)
                    .padding(.horizontal)
                    
                    // Event Selection Dropdown
                    if !availableEventIds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Sleep Event:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(availableEventIds, id: \.self) { eventId in
                                    Button("Event \(eventId)") {
                                        selectedEventId = eventId
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedEventId != nil ? "Event \(selectedEventId!)" : "Select Event")
                                        .foregroundColor(selectedEventId != nil ? .primary : .secondary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Fetch Buttons Section
                    if selectedEventId != nil {
                        VStack(spacing: 12) {
                            // Fetch Event Plots Button
                            Button(action: fetchEventPlots) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text("Fetch Event \(selectedEventId!) Trends")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isLoadingEventPlots)
                            
                            // Fetch Baseline Plots Button
                            Button(action: fetchBaselinePlots) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Fetch Sleep Baseline Trends")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.indigo)
                                .cornerRadius(12)
                            }
                            .disabled(isLoadingBaselinePlots)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Loading States
                    if isLoadingEvents {
                        ProgressView("Loading sleep events...")
                            .padding()
                    }
                    
                    if isLoadingEventPlots {
                        ProgressView("Generating event plots...")
                            .padding()
                    }
                    
                    if isLoadingBaselinePlots {
                        ProgressView("Generating baseline plots...")
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
                    
                    // Sleep Event Trends Section
                    if !eventPlots.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sleep Event Trends")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                if let eventId = selectedEventId {
                                    Text("Event \(eventId) - \(eventSessionCount) sessions")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(metricsOrder, id: \.self) { metric in
                                    if let plotResult = eventPlots[metric] {
                                        HRVPlotCard(
                                            title: "\(displayMetrics[metric] ?? metric.uppercased()) - Event Trends",
                                            plotResult: plotResult,
                                            tag: "sleep_event"
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Sleep Baseline Trends Section
                    if !baselinePlots.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sleep Baseline Trends")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Averaged across \(baselineEventsCount) sleep events")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(metricsOrder, id: \.self) { metric in
                                    if let plotResult = baselinePlots[metric] {
                                        HRVPlotCard(
                                            title: "\(displayMetrics[metric] ?? metric.uppercased()) - Baseline Trends",
                                            plotResult: plotResult,
                                            tag: "sleep_baseline"
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Auto-load events when tab appears
            if availableEventIds.isEmpty {
                loadSleepEvents()
            }
        }
    }
    
    private func loadSleepEvents() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        isLoadingEvents = true
        errorMessage = nil
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/sleep/events/\(userId)?limit=7"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoadingEvents = false
            return
        }
        
        print("🌙 SLEEP: Loading events from: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoadingEvents = false
                
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
                        if let eventIds = jsonResponse?["event_ids"] as? [Int] {
                            availableEventIds = eventIds
                            if !eventIds.isEmpty && selectedEventId == nil {
                                selectedEventId = eventIds.first
                            }
                        }
                    } else {
                        let errorMsg = jsonResponse?["error"] as? String ?? "Unknown error"
                        errorMessage = "API error: \(errorMsg)"
                    }
                    
                } catch {
                    errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func fetchEventPlots() {
        guard let userId = coreEngine.userId,
              let eventId = selectedEventId else {
            errorMessage = "Missing user ID or event ID"
            return
        }
        
        isLoadingEventPlots = true
        errorMessage = nil
        eventPlots = [:]
        eventSessionCount = 0
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/sleep-event/\(userId)/\(eventId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoadingEventPlots = false
            return
        }
        
        print("🌙 SLEEP: Fetching event plots from: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add request body with metrics array
        let requestBody = ["metrics": ["rmssd", "sdnn"]]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoadingEventPlots = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingEventPlots = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                processPlotResponse(data: data, plotsDict: &eventPlots, sessionCountKey: "sessions_count") { count in
                    eventSessionCount = count
                }
            }
        }.resume()
    }
    
    private func fetchBaselinePlots() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        isLoadingBaselinePlots = true
        errorMessage = nil
        baselinePlots = [:]
        baselineEventsCount = 0
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/sleep-baseline/\(userId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoadingBaselinePlots = false
            return
        }
        
        print("🌙 SLEEP: Fetching baseline plots from: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add request body with metrics array
        let requestBody = ["metrics": ["rmssd", "sdnn"]]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            isLoadingBaselinePlots = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingBaselinePlots = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                processPlotResponse(data: data, plotsDict: &baselinePlots, sessionCountKey: "events_count") { count in
                    baselineEventsCount = count
                }
            }
        }.resume()
    }
    
    private func processPlotResponse(data: Data, plotsDict: inout [String: PlotResult], sessionCountKey: String, countCallback: @escaping (Int) -> Void) {
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let success = jsonResponse?["success"] as? Bool, success {
                let count = jsonResponse?[sessionCountKey] as? Int ?? 0
                countCallback(count)
                
                if let plotsData = jsonResponse?["plots"] as? [String: [String: Any]] {
                    for (metric, plotData) in plotsData {
                        if let success = plotData["success"] as? Bool, success,
                           let plotDataString = plotData["plot_data"] as? String,
                           !plotDataString.isEmpty {
                            
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
                                
                                plotsDict[metric] = PlotResult(
                                    image: image,
                                    statistics: statistics
                                )
                            }
                        } else {
                            let errorMsg = plotData["error"] as? String ?? "Unknown error"
                            print("❌ Error generating \(metric) sleep plot: \(errorMsg)")
                        }
                    }
                }
                
                if plotsDict.isEmpty {
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

#Preview {
    SleepTabView()
        .environmentObject(CoreEngine.shared)
}
