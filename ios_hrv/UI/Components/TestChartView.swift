import SwiftUI
import Charts

/// Test chart component for sleep intervals with timestamp precision
/// Isolated for debugging chronological plotting issues
struct TestChartView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: TestChartViewModel
    let height: CGFloat
    
    // MARK: - Initialization
    
    init(viewModel: TestChartViewModel, height: CGFloat = 300) {
        self.viewModel = viewModel
        self.height = height
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Header
            chartHeader
            
            // Main Chart
            chartContent
            
            // Debug Info
            debugInfoCard
            
            // Chart Footer
            chartFooter
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Chart Header
    
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.chartTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: viewModel.refreshTestData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Text(viewModel.chartDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if viewModel.hasData {
                Text(viewModel.statisticsSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Chart Content
    
    private var chartContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.hasData {
                testChart
            } else {
                emptyStateView
            }
        }
        .frame(height: height)
    }
    
    // MARK: - Test Chart Implementation with Timestamp Precision
    
    private var testChart: some View {
        Chart {
            // Get sorted data for chronological display with timestamp precision
            let sortedData = viewModel.testData?.raw.sorted { $0.dateValue < $1.dateValue } ?? []
            let sortedRollingAvg = viewModel.testData?.rollingAvg?.sorted { $0.dateValue < $1.dateValue } ?? []
            
            // Layer 5: SD Band (AreaMark) - Blue.opacity fill
            if let config = viewModel.chartConfig,
               config.showSDBand,
               let sdBand = viewModel.testData?.sdBand,
               !sortedData.isEmpty {
                
                ForEach(sortedData) { point in
                    AreaMark(
                        x: .value("Timestamp", point.dateValue),
                        yStart: .value("Lower", sdBand.lower),
                        yEnd: .value("Upper", sdBand.upper)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
            }
            
            // Layer 4: 10/90 Percentiles (RuleMark) - Dashed Gray
            if let config = viewModel.chartConfig,
               config.showPercentiles,
               let p10 = viewModel.testData?.percentile10,
               let p90 = viewModel.testData?.percentile90 {
                
                RuleMark(y: .value("10th Percentile", p10))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing) {
                        Text("10th")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                
                RuleMark(y: .value("90th Percentile", p90))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing) {
                        Text("90th")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
            }
            
            // Layer 3: Baseline (RuleMark) - Solid Gray
            if let config = viewModel.chartConfig,
               config.showBaseline,
               let baseline = viewModel.testData?.baseline {
                
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .trailing) {
                        Text("Baseline")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
            }
            
            // Layer 2: Rolling Average (LineMark) - SINGLE Continuous Line
            // CRITICAL FIX: Use single LineMark with series to create ONE continuous line
            // This matches Python Plotly's single go.Scatter approach
            if let config = viewModel.chartConfig,
               config.showRollingAverage,
               !sortedRollingAvg.isEmpty {
                
                // CORRECT APPROACH: Single continuous line using series identifier
                ForEach(sortedRollingAvg) { point in
                    LineMark(
                        x: .value("Timestamp", point.dateValue),
                        y: .value("Rolling Avg", point.rmssd),
                        series: .value("Series", "rolling_average")
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .interpolationMethod(.linear)
                }
            }
            
            // Layer 1: Raw RMSSD (LineMark + PointMark) - Solid Blue
            if let config = viewModel.chartConfig,
               config.showRawData,
               !sortedData.isEmpty {
                
                // Continuous line connecting all points with timestamp precision
                ForEach(sortedData) { point in
                    LineMark(
                        x: .value("Timestamp", point.dateValue),
                        y: .value("RMSSD", point.rmssd)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                
                // Individual data points
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
        .chartXScale(domain: viewModel.xAxisDomain)  // Use precise timestamp domain
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute().second())  // Show time precision
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(doubleValue, specifier: "%.1f")")
                    }
                }
            }
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
            }
        }
        .chartOverlay { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Handle chart tap for future interactivity
                    }
            }
        }
    }
    
    // MARK: - Debug Info Card
    
    private var debugInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Info")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Debug API") {
                    viewModel.debugAPIResponse()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            Text(viewModel.debugInfo)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(4)
            
            if viewModel.hasData {
                Text(viewModel.timestampRangeInfo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    // MARK: - Chart Footer
    
    private var chartFooter: some View {
        HStack {
            // Legend
            testChartLegend
            
            Spacer()
            
            // Data info
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.dataPointCount) intervals")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Test Mode")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Test Chart Legend
    
    private var testChartLegend: some View {
        HStack(spacing: 12) {
            if let config = viewModel.chartConfig {
                if config.showRawData {
                    legendItem(color: .blue, style: .solid, label: "RMSSD")
                }
                
                if config.showRollingAverage {
                    legendItem(color: .blue.opacity(0.7), style: .dashed, label: "Rolling Avg")
                }
                
                if config.showBaseline {
                    legendItem(color: .gray, style: .solid, label: "Baseline")
                }
                
                if config.showSDBand {
                    legendItem(color: .blue.opacity(0.2), style: .area, label: "SD Band")
                }
                
                if config.showPercentiles {
                    legendItem(color: .gray, style: .dashed, label: "Percentiles")
                }
            }
        }
    }
    
    private func legendItem(color: Color, style: LegendStyle, label: String) -> some View {
        HStack(spacing: 4) {
            switch style {
            case .solid:
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 2)
            case .dashed:
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 2)
                    .overlay(
                        Rectangle()
                            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    )
            case .area:
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 8)
                    .cornerRadius(2)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading test data...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Test Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                viewModel.refreshTestData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Test Data")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No sleep intervals found for testing.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                viewModel.refreshTestData()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Legend Style

private enum LegendStyle {
    case solid
    case dashed
    case area
}

// MARK: - Preview

#Preview {
    TestChartView(viewModel: TestChartViewModel.mockViewModel())
        .padding()
}
