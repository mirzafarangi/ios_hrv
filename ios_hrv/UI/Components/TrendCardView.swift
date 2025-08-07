import SwiftUI

/// Individual trend card for the three-card layout
/// Clean, minimal design with chart and basic info
struct TrendCardView: View {
    let type: TrendType
    let data: TrendData?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Data count badge
                if let data = data {
                    Text("\(data.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(type.color))
                        .clipShape(Capsule())
                }
            }
            
            // Content
            if isLoading {
                LoadingChartView()
            } else if let data = data, !data.data.isEmpty {
                TrendChartView(
                    data: data.chartDataPoints,
                    type: type,
                    statistics: data.statistics
                )
            } else {
                EmptyDataView(type: type)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// Loading state for chart
struct LoadingChartView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading chart data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

/// Empty data state
struct EmptyDataView: View {
    let type: TrendType
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            
            Text("No \(type.rawValue.lowercased()) data")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Record some sessions to see trends")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let sampleData = TrendData(
        data: [
            DataPoint(
                recordedAt: Date(),
                rmssd: 45.2,
                sdnn: 52.1,
                meanHr: 65.0,
                meanRr: 923.0,
                countRr: 120,
                pnn50: 15.2,
                cvRr: 5.6,
                defa: 1.2,
                sd2Sd1: 2.8,
                subtag: "rest_single",
                eventId: nil,
                eventStart: nil,
                avgRmssd: nil,
                avgSdnn: nil,
                intervalCount: nil
            )
        ],
        count: 1,
        description: "Individual rest sessions",
        latestEventId: nil
    )
    
    VStack(spacing: 16) {
        TrendCardView(type: .rest, data: sampleData, isLoading: false)
        TrendCardView(type: .sleepEvent, data: nil, isLoading: true)
        TrendCardView(type: .sleepBaseline, data: nil, isLoading: false)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
