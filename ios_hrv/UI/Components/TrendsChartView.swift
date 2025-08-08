import SwiftUI
import Charts

/// Trends chart view for proper HRV analysis visualization
/// Responds to user metric and mode selections, displays correct trend data
struct TrendsChartView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = TrendsChartViewModel()
    let selectedMetric: HRVMetric
    let selectedMode: TrendMode
    let height: CGFloat
    // Optional upward callbacks for legend/stats/debug consumers
    var onStatsUpdate: ((String) -> Void)? = nil
    var onDebugJSONUpdate: ((String) -> Void)? = nil
    
    // MARK: - Computed Properties
    
    private var chartYScale: ClosedRange<Double> {
        // Use full-response derived domain (raw + overlays)
        viewModel.yAxisDomain
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.hasData {
                chartView
            } else {
                emptyStateView
            }
        }
        .frame(height: height)
        .onAppear {
            loadData()
        }
        .onChange(of: selectedMetric) { _ in
            loadData()
        }
        .onChange(of: selectedMode) { _ in
            loadData()
        }
        // Bubble up statistics/debug strings when they change
        .onChange(of: viewModel.statisticsSummary) { newValue in
            onStatsUpdate?(newValue)
        }
        .onChange(of: viewModel.debugRawJSON) { newValue in
            onDebugJSONUpdate?(newValue)
        }
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        Chart {
            // Prepare sorted series for timestamp-precise rendering
            let sortedData = (viewModel.response?.raw ?? viewModel.chartData).sorted { $0.dateValue < $1.dateValue }
            let stats = viewModel.rollingStats.sorted { $0.date < $1.date }

            // Layer 5 (bottom): SD2 cloud (continuous, light red)
            if !stats.isEmpty {
                ForEach(stats) { p in
                    AreaMark(
                        x: .value("Timestamp", p.date),
                        yStart: .value("SD2 Low", p.sd2Low),
                        yEnd: .value("SD2 High", p.sd2High),
                        series: .value("Band", "SD2")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(.red.opacity(0.22))
                }
            }

            // Layer 4: SD1 cloud (continuous, amber) on top of SD2
            if !stats.isEmpty {
                ForEach(stats) { p in
                    AreaMark(
                        x: .value("Timestamp", p.date),
                        yStart: .value("SD1 Low", p.sd1Low),
                        yEnd: .value("SD1 High", p.sd1High),
                        series: .value("Band", "SD1")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(.orange.opacity(0.32))
                }
            }

            // Layer 3: Rolling 3-point mean (green, dashed)
            if !viewModel.rollingMeanSeries.isEmpty {
                ForEach(viewModel.rollingMeanSeries.sorted { $0.date < $1.date }) { p in
                    LineMark(
                        x: .value("Timestamp", p.date),
                        y: .value("3pt Mean", p.value),
                        series: .value("Series", "rolling_3pt")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .interpolationMethod(.linear)
                }
            }

            // Layer 2: Baseline (if present)
            if let baseline = viewModel.response?.baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Layer 1 (top): Raw RMSSD points (blue)
            if let config = viewModel.chartConfig,
               config.showRawData,
               !sortedData.isEmpty {
                ForEach(sortedData) { point in
                    PointMark(
                        x: .value("Timestamp", point.dateValue),
                        y: .value("RMSSD", point.rmssd)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(16)
                }
            }
        }
        .chartYScale(domain: viewModel.yAxisDomain)
        .chartXScale(domain: viewModel.xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute().second())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading \(selectedMetric.displayName.lowercased()) trend...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Analysis Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("No \(selectedMetric.displayName) Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No data available for \(selectedMode.displayName.lowercased()) analysis")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadData() {
        viewModel.loadTrendData(metric: selectedMetric, mode: selectedMode)
    }
}

// MARK: - Preview

struct TrendsChartView_Previews: PreviewProvider {
    static var previews: some View {
        TrendsChartView(
            selectedMetric: .rmssd,
            selectedMode: .rest,
            height: 300
        )
        .padding()
    }
}
