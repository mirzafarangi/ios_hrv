import SwiftUI

/// Test tab for debugging chronological plotting issues
/// Isolated test environment for Sleep Interval analysis with timestamp precision
struct TestTabView: View {
    
    // MARK: - State
    
    @StateObject private var viewModel = TestChartViewModel()
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Test Info Card
                    testInfoCard
                    
                    // Test Chart
                    TestChartView(viewModel: viewModel, height: 350)
                    
                    // Test Controls
                    testControlsCard
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Test Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.refreshTestData()
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Test Info Card
    
    private var testInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(.orange)
                
                Text("Test Environment")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                testInfoRow(
                    icon: "target",
                    title: "Purpose",
                    description: "Debug chronological plotting with timestamp precision"
                )
                
                testInfoRow(
                    icon: "clock.fill",
                    title: "X-Axis Scaling",
                    description: "1-second accuracy instead of daily aggregation"
                )
                
                testInfoRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Analysis Type",
                    description: "Sleep Intervals from latest sleep event"
                )
                
                testInfoRow(
                    icon: "slider.horizontal.3",
                    title: "Thresholds",
                    description: "Reduced to 5 points for percentiles (testing mode)"
                )
            }
            
            Divider()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("This is an isolated test environment. Changes here won't affect main charts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func testInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Test Controls Card
    
    private var testControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Controls")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Refresh Data Button
                Button(action: {
                    viewModel.refreshTestData()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Test Data")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                // Debug API Button
                Button(action: {
                    viewModel.debugAPIResponse()
                }) {
                    HStack {
                        Image(systemName: "network")
                        Text("Debug API Response")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Test Status
                testStatusView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var testStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Status")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Circle()
                    .fill(viewModel.hasData ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.hasData ? "Data Available" : "No Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.hasData {
                    Text("\(viewModel.dataPointCount) intervals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    TestTabView()
}
