import SwiftUI

/// Clean empty Charts tab placeholder
/// All chart/trend functionality has been removed for clean regression
struct ChartsTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Charts")
                    .font(.title)
                    .fontWeight(.medium)
                
                Text("Chart functionality will be implemented here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .navigationTitle("Charts")
        }
    }
}

#Preview {
    ChartsTabView()
}
