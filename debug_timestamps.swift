import Foundation

// Debug script to test timestamp parsing
let testTimestamps = [
    "2025-08-07T18:49:57+00:00",
    "2025-08-07T19:02:38+00:00", 
    "2025-08-07T19:03:39+00:00"
]

print("🔍 DEBUGGING iOS TIMESTAMP PARSING")
print("=" * 50)

let formatter1 = ISO8601DateFormatter()
formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

let formatter2 = ISO8601DateFormatter()
formatter2.formatOptions = [.withInternetDateTime]

let formatter3 = DateFormatter()
formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

for timestamp in testTimestamps {
    print("Timestamp: \(timestamp)")
    
    let date1 = formatter1.date(from: timestamp)
    let date2 = formatter2.date(from: timestamp)
    let date3 = formatter3.date(from: timestamp)
    
    print("  - ISO8601 with fractional: \(date1?.description ?? "FAILED")")
    print("  - ISO8601 without fractional: \(date2?.description ?? "FAILED")")
    print("  - Custom formatter: \(date3?.description ?? "FAILED")")
    print()
}
