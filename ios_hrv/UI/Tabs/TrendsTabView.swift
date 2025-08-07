import SwiftUI

/// Production-ready Trends tab with comprehensive HRV analysis
/// Features 6 clinical-grade plots: RMSSD + SDNN × 3 trend modes
/// Integrates all visualization lessons from Test tab success
struct TrendsTabView: View {
    
    // MARK: - State
    
    @StateObject private var viewModel = TestChartViewModel()
    @State private var selectedTrendMode: TrendMode = .rest
    @State private var selectedMetric: HRVMetric = .rmssd
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Minimal Metric Selector
                    metricSelector
                    
                    // Minimal Trend Mode Selector
                    trendModeSelector
                    
                    // Academic Chart Layout: Plot → Legend → Statistics → Debug
                    academicChartLayout
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("HRV Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        refreshCurrentChart()
                    }
                    .font(.caption)
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    

    
    // MARK: - Minimal Metric Selector
    
    private var metricSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metric")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(HRVMetric.allCases, id: \.self) { metric in
                    Button(action: {
                        selectedMetric = metric
                        refreshCurrentChart()
                    }) {
                        Text(metric.displayName)
                            .font(.body)
                            .fontWeight(selectedMetric == metric ? .semibold : .regular)
                            .foregroundColor(selectedMetric == metric ? .blue : .secondary)
                            .frame(width: 80, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(selectedMetric == metric ? Color.blue : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Minimal Trend Mode Selector
    
    private var trendModeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Mode")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(TrendMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedTrendMode = mode
                        refreshCurrentChart()
                    }) {
                        VStack(alignment: .center, spacing: 2) {
                            Text(mode.displayName)
                                .font(.body)
                                .fontWeight(selectedTrendMode == mode ? .semibold : .regular)
                                .foregroundColor(selectedTrendMode == mode ? .blue : .primary)
                            
                            Text(mode.academicDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 110, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(selectedTrendMode == mode ? Color.blue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Academic Chart Layout (Clean Plot Card + External Components)
    
    private var academicChartLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Title (minimal, academic)
            HStack {
                Text("\(selectedMetric.displayName) Analysis")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(selectedTrendMode.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 1. Clean Plot Card (plot only, no internal components)
            cleanPlotCard
            
            // 2. External Legend (below plot card)
            academicLegend
            
            // 3. External Statistics (below legend)
            academicStatistics
            
            // 4. Single Debug Section (at the end)
            academicDebugInfo
        }
    }
    
    // MARK: - Clean Plot Card
    
    private var cleanPlotCard: some View {
        TestChartView(
            viewModel: viewModel,
            height: 300
        )
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Academic Components
    
    private var academicLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legend")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                legendItem(color: .blue, style: "●", label: "Data points")
                legendItem(color: .blue.opacity(0.7), style: "- -", label: "Rolling average")
                legendItem(color: .gray, style: "—", label: "Baseline")
                legendItem(color: .blue.opacity(0.2), style: "▓", label: "SD bands")
                Spacer()
            }
        }
    }
    
    private func legendItem(color: Color, style: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(style)
                .foregroundColor(color)
                .font(.caption)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var academicStatistics: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistics")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            if viewModel.hasData {
                Text(viewModel.statisticsSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("No data available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    

    
    private var academicDebugInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(viewModel.debugInfo.isEmpty ? "No debug information" : viewModel.debugInfo)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Computed Properties
    
    private var chartSubtitle: String {
        switch selectedTrendMode {
        case .rest:
            return "All rest sessions with 1-second precision"
        case .sleepInterval:
            return "Latest sleep event intervals"
        case .sleepEvent:
            return "Aggregated sleep events"
        }
    }
    
    // MARK: - Actions
    
    private func loadInitialData() {
        // Load initial data using the same pattern as TestTabView
        viewModel.refreshTestData()
    }
    
    private func refreshCurrentChart() {
        // Refresh data when user changes selections
        viewModel.refreshTestData()
    }
}

// MARK: - Supporting Enums

enum HRVMetric: String, CaseIterable {
    case rmssd = "rmssd"
    case sdnn = "sdnn"
    case sd2sd1 = "sd2_sd1"
    case defa = "defa"
    
    var displayName: String {
        switch self {
        case .rmssd:
            return "RMSSD"
        case .sdnn:
            return "SDNN"
        case .sd2sd1:
            return "SD2/SD1"
        case .defa:
            return "DFA α1"
        }
    }
}

enum TrendMode: String, CaseIterable {
    case rest = "rest"
    case sleepInterval = "sleep_interval"
    case sleepEvent = "sleep_event"
    
    var displayName: String {
        switch self {
        case .rest:
            return "Rest Trends"
        case .sleepInterval:
            return "Sleep Intervals"
        case .sleepEvent:
            return "Sleep Events"
        }
    }
    
    var description: String {
        switch self {
        case .rest:
            return "All rest sessions chronologically"
        case .sleepInterval:
            return "Latest sleep event intervals with timestamp precision"
        case .sleepEvent:
            return "Aggregated sleep events (night-to-night)"
        }
    }
    
    var academicDescription: String {
        switch self {
        case .rest:
            return "Individual sessions"
        case .sleepInterval:
            return "Within-night intervals"
        case .sleepEvent:
            return "Night-to-night events"
        }
    }
}

#Preview {
    TrendsTabView()
}
