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
    @State private var baselineSessionCount = 0
    @State private var currentEventTask: URLSessionDataTask?
    @State private var currentBaselineTask: URLSessionDataTask?
    
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
                        
                        Text("Direct API HRV Trends")
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
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingEvents)
                    .padding(.horizontal)
                    
                    // Loading indicator for events
                    if isLoadingEvents {
                        ProgressView("Loading sleep events...")
                            .padding()
                    }
                    
                    // Events List
                    if !availableEventIds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Sleep Events")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableEventIds, id: \.self) { eventId in
                                        Button(action: {
                                            selectedEventId = eventId
                                            fetchEventPlots(eventId: eventId)
                                        }) {
                                            VStack {
                                                Text("Event \(eventId)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(selectedEventId == eventId ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedEventId == eventId ? .white : .primary)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Fetch Baseline Button
                    Button(action: fetchSleepBaseline) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Fetch Sleep Baseline Trends")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingBaselinePlots)
                    .padding(.horizontal)
                    
                    // Loading indicators
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
                    
                    // Event Plots Section
                    if !eventPlots.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Sleep Event \(selectedEventId ?? 0) Trends")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(eventSessionCount) sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(metricsOrder, id: \.self) { metric in
                                if let plotResult = eventPlots[metric] {
                                    HRVPlotCard(
                                        title: displayMetrics[metric] ?? metric.uppercased(),
                                        plotResult: plotResult,
                                        tag: "sleep-event"
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Baseline Plots Section
                    if !baselinePlots.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Sleep Baseline Trends")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(baselineSessionCount) sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(metricsOrder, id: \.self) { metric in
                                if let plotResult = baselinePlots[metric] {
                                    HRVPlotCard(
                                        title: displayMetrics[metric] ?? metric.uppercased(),
                                        plotResult: plotResult,
                                        tag: "sleep-baseline"
                                    )
                                    .padding(.horizontal)
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
        .onDisappear {
            // Cancel any active requests when leaving tab
            cancelAllRequests()
        }
    }
    
    // MARK: - Request Management & Cancellation
    
    private func cancelAllRequests() {
        print("🚫 SLEEP: Cancelling all active requests")
        currentEventTask?.cancel()
        currentBaselineTask?.cancel()
        currentEventTask = nil
        currentBaselineTask = nil
        
        // Reset loading states
        isLoadingEvents = false
        isLoadingEventPlots = false
        isLoadingBaselinePlots = false
    }
    
    // MARK: - Direct API Methods Following Rest Tab Pattern
    
    private func loadSleepEvents() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        // Cancel any existing request to prevent response mixing
        currentEventTask?.cancel()
        
        isLoadingEvents = true
        errorMessage = nil
        availableEventIds = []
        selectedEventId = nil
        
        // Query database directly for available sleep event IDs
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/sessions/processed/\(userId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoadingEvents = false
            return
        }
        
        print("🟢 SLEEP: Loading events from: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                    
                    if let sessions = jsonResponse?["sessions"] as? [[String: Any]] {
                        // Extract unique event IDs for sleep sessions
                        let sleepSessions = sessions.filter { session in
                            return (session["tag"] as? String) == "sleep"
                        }
                        
                        let eventIds = Set(sleepSessions.compactMap { session in
                            session["event_id"] as? Int
                        }).filter { $0 > 0 } // Only positive event IDs
                        
                        availableEventIds = Array(eventIds).sorted()
                        
                        print("🔍 SLEEP: Found \(availableEventIds.count) sleep events: \(availableEventIds)")
                        
                        if availableEventIds.isEmpty {
                            errorMessage = "No sleep events found"
                        }
                    } else {
                        errorMessage = "Invalid response format"
                    }
                    
                } catch {
                    errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }
        
        currentEventTask = task
        task.resume()
    }
    
    private func fetchEventPlots(eventId: Int) {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        // Cancel any existing request to prevent response mixing
        currentEventTask?.cancel()
        
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
        
        print("🟢 SLEEP: Fetching event plots from: \(urlString)")
        
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
            isLoadingEventPlots = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                
                processPlotResponse(data: data, plotsDict: &eventPlots) { count in
                    eventSessionCount = count
                }
            }
        }
        
        currentEventTask = task
        task.resume()
    }
    
    private func fetchSleepBaseline() {
        guard let userId = coreEngine.userId else {
            errorMessage = "No authenticated user found"
            return
        }
        
        // Cancel any existing request to prevent response mixing
        currentBaselineTask?.cancel()
        
        isLoadingBaselinePlots = true
        errorMessage = nil
        baselinePlots = [:]
        baselineSessionCount = 0
        
        let urlString = "https://hrv-brain-api-production.up.railway.app/api/v1/plots/sleep-baseline/\(userId)"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoadingBaselinePlots = false
            return
        }
        
        print("🟢 SLEEP: Fetching baseline plots from: \(urlString)")
        
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
            isLoadingBaselinePlots = false
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                
                processPlotResponse(data: data, plotsDict: &baselinePlots) { count in
                    baselineSessionCount = count
                }
            }
        }
        
        currentBaselineTask = task
        task.resume()
    }
    
    private func processPlotResponse(data: Data, plotsDict: inout [String: PlotResult], sessionCountCallback: @escaping (Int) -> Void) {
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("🔍 SLEEP: Raw response keys: \(jsonResponse?.keys.sorted() ?? [])")
            
            if let success = jsonResponse?["success"] as? Bool, success {
                let sessionCount = jsonResponse?["sessions_count"] as? Int ?? 0
                sessionCountCallback(sessionCount)
                print("🔍 SLEEP: Success=\(success), Sessions=\(sessionCount)")
                
                if let plotsData = jsonResponse?["plots"] as? [String: [String: Any]] {
                    print("🔍 SLEEP: Found plots data with metrics: \(plotsData.keys.sorted())")
                    for (metric, plotData) in plotsData {
                        let plotSuccess = plotData["success"] as? Bool ?? false
                        let plotDataString = plotData["plot_data"] as? String ?? ""
                        let plotError = plotData["error"] as? String
                        print("🔍 SLEEP: \(metric) - success=\(plotSuccess), data_length=\(plotDataString.count), error=\(plotError ?? "none")")
                        
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
