import SwiftUI
import Charts

/// Minimal, clean chart view for HRV trends
/// No cream style - simple, functional plotting
struct TrendChartView: View {
    let data: [ChartDataPoint]
    let type: TrendType
    let statistics: TrendStatistics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Chart
            if data.isEmpty {
                EmptyChartView()
            } else {
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("RMSSD", point.rmssd)
                    )
                    .foregroundStyle(Color(type.color))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("RMSSD", point.rmssd)
                    )
                    .foregroundStyle(Color(type.color))
                    .symbolSize(30)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
            
            // Statistics
            if let stats = statistics {
                StatisticsView(statistics: stats)
            }
        }
    }
}

/// Empty state for charts with no data
struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

/// Minimal statistics display
struct StatisticsView: View {
    let statistics: TrendStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(statistics.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                StatItem(label: "RMSSD", value: statistics.rmssdMean, unit: "ms")
                StatItem(label: "SDNN", value: statistics.sdnnMean, unit: "ms")
            }
            
            HStack(spacing: 20) {
                StatItem(label: "Min", value: statistics.rmssdMin, unit: "ms")
                StatItem(label: "Max", value: statistics.rmssdMax, unit: "ms")
            }
        }
        .padding(.top, 8)
    }
}

/// Individual statistic item
struct StatItem: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(value, specifier: "%.1f") \(unit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    let sampleData = [
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 7), rmssd: 45.2, sdnn: 52.1),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 6), rmssd: 48.7, sdnn: 55.3),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 5), rmssd: 42.1, sdnn: 49.8),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 4), rmssd: 46.9, sdnn: 53.2),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 3), rmssd: 44.3, sdnn: 51.7),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 2), rmssd: 47.8, sdnn: 54.9),
        ChartDataPoint(date: Date().addingTimeInterval(-86400 * 1), rmssd: 43.6, sdnn: 50.4)
    ]
    
    let stats = TrendStatistics(
        count: 7,
        rmssdMean: 45.5,
        rmssdMin: 42.1,
        rmssdMax: 48.7,
        sdnnMean: 52.5,
        sdnnMin: 49.8,
        sdnnMax: 55.3
    )
    
    TrendChartView(data: sampleData, type: .rest, statistics: stats)
        .padding()
}
