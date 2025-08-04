# HRV Brain iOS App - Production System v5.0.0
**Complete iOS Implementation with Direct Database Integration**

> **🎯 BLUEPRINT STATUS**: This README serves as the canonical setup guide for the iOS app. Follow these instructions for guaranteed successful build and deployment.

**Version:** 5.0.0 FINAL  
**Platform:** iOS 15.0+ / Swift 5.7+ / SwiftUI  
**Architecture:** Clean Architecture + Direct Supabase Integration  
**Status:** ✅ Production Ready + Database Integrated  
**Database Access:** Direct PostgREST client (Supabase Swift SDK)  
**Authentication:** Hybrid HTTP + SDK approach  

## 🏗️ **ARCHITECTURE OVERVIEW**

### **Core Design Principles**
- **Clean Architecture**: Separation of concerns with Core, Models, UI, Utilities layers
- **Direct Database Access**: Sessions tab reads directly from PostgreSQL via PostgREST
- **Hybrid Authentication**: HTTP-based auth + SDK-based data queries
- **Unified Data Models**: Exact schema matching with API and database
- **Comprehensive Debugging**: Built-in diagnostics and error reporting

### **Key Components**
```
ios_hrv/
├── Core/
│   ├── CoreEngine.swift           # Main app coordinator
│   ├── SupabaseAuthService.swift  # HTTP-based authentication
│   ├── DatabaseSessionManager.swift # Direct PostgREST database access
│   ├── SupabaseConfig.swift       # Hybrid Supabase configuration
│   └── RecordingManager.swift     # Session recording logic
├── Models/
│   └── UnifiedModels.swift        # Database-aligned data models
├── UI/
│   ├── Tabs/
│   │   ├── RecordTabView.swift    # HRV session recording
│   │   ├── SessionsTabView.swift  # Direct database sessions display
│   │   └── ProfileTabView.swift   # User profile and settings
│   └── Components/
│       └── SessionComponents.swift # Session display components
└── Utilities/
    └── CoreLogger.swift           # Comprehensive logging system
```

## 🔧 **CRITICAL ARCHITECTURE DECISIONS**

### **1. Hybrid Supabase Integration**
```swift
// Authentication: HTTP-based (stable, working)
SupabaseAuthService.shared.signIn(email: email, password: password)

// Database Queries: Supabase Swift SDK PostgREST module
let sessions: [DatabaseSession] = try await SupabaseConfig.client
    .from("sessions")
    .select("session_id, user_id, tag, subtag, ...")
    .eq("user_id", value: userId)
    .execute()
    .value
```

### **2. Direct Database Access Pattern**
- **Sessions Tab**: Bypasses API, queries PostgreSQL directly via PostgREST
- **Real-time Data**: No caching layers, always fresh from database
- **Debug Diagnostics**: Built-in pipeline debugging and connection monitoring

### **3. Unified Data Models**
```swift
struct DatabaseSession: Codable, Identifiable {
    let sessionId: String      // session_id (UUID)
    let userId: String         // user_id (UUID)
    let tag: String           // "rest", "sleep", "exercise"
    let subtag: String        // "rest_single", "sleep_interval_1"
    let eventId: Int          // 0 for standalone, >0 for grouped
    
    // All 9 HRV Metrics (matching database schema exactly)
    let meanHr: Double?       // mean_hr
    let meanRr: Double?       // mean_rr
    let countRr: Int?         // count_rr
    let rmssd: Double?        // rmssd
    let sdnn: Double?         // sdnn
    let pnn50: Double?        // pnn50
    let cvRr: Double?         // cv_rr
    let defa: Double?         // defa
    let sd2Sd1: Double?       // sd2_sd1
}
```

## 📦 **DEPENDENCIES & CONFIGURATION**

### **Required Swift Packages**
```swift
// Package.swift dependencies
.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.31.1")

// Specific modules used:
- PostgREST (for database queries)
- Auth (for authentication, if needed)
```

### **Supabase Configuration**
```swift
struct SupabaseConfig {
    static let url = "https://hmckwsyksbckxfxuzxca.supabase.co"
    static let anonKey = "sb_publishable_oRjabmXPVvT5QMv_5Ec92A_Ytc6xrFr"
    
    // PostgREST client for database operations
    static let client = PostgrestClient(
        url: URL(string: "\(url)/rest/v1")!,
        schema: "public",
        headers: [
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)"
        ],
        logger: nil
    )
}
```

## 🎯 **BUILD & DEPLOYMENT**

### **Build Requirements**
- **Xcode**: 15.0+
- **iOS Deployment Target**: 15.0+
- **Swift Version**: 5.7+
- **Supabase Swift SDK**: 2.31.1

### **Build Command**
```bash
cd /path/to/ios_hrv
xcodebuild -project ios_hrv.xcodeproj \
           -scheme ios_hrv \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

### **Expected Build Output**
```
** BUILD SUCCEEDED **
```

## 🔍 **SESSIONS TAB ARCHITECTURE**

### **Direct Database Integration**
```swift
class DatabaseSessionManager: ObservableObject {
    @Published var sessions: [DatabaseSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugInfo: [String] = []
    
    func loadSessions(for userId: String) {
        // Get authenticated user token
        guard let userToken = await SupabaseAuthService.shared.getCurrentAccessToken()
        
        // Create authenticated PostgREST client
        let authenticatedClient = PostgrestClient(
            url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
            headers: [
                "apikey": SupabaseConfig.anonKey,
                "Authorization": "Bearer \(userToken)"
            ]
        )
        
        // Query sessions directly from database
        let response: [DatabaseSession] = try await authenticatedClient
            .from("sessions")
            .select("session_id, user_id, tag, subtag, ...")
            .eq("user_id", value: userId)
            .order("recorded_at", ascending: false)
            .execute()
            .value
    }
}
```

### **UI Components**
- **SessionDataCard**: Displays individual session with all HRV metrics
- **DebugDiagnosticsCard**: Shows connection status, authentication info, pipeline debugging
- **EmptySessionsCard**: Helpful empty state with guidance

## 🐛 **DEBUGGING & DIAGNOSTICS**

### **Built-in Debug Features**
- **Authentication Status**: Real-time auth token validation
- **Database Connection**: PostgREST client status and errors
- **Query Debugging**: Detailed SQL query logging and results
- **Error Analysis**: Comprehensive error categorization and hints

### **Debug Information Displayed**
```swift
// Example debug output in Sessions tab
"🔄 Starting Supabase Swift SDK session load for user: 12345"
"🔐 Using authenticated user token"
"📊 Database Schema: v5.0.0 FINAL"
"🔗 Connection: Supabase Swift SDK → PostgreSQL"
"✅ Successfully loaded 5 sessions via Supabase Swift SDK"
"📈 Session types: rest, sleep"
"✅ Completed: 5/5"
"📊 With HRV metrics: 5/5"
```

## 🔧 **TROUBLESHOOTING**

### **Common Build Issues**
1. **"No such module 'Supabase'"**
   - Solution: Import `PostgREST` and `Auth` modules individually
   - Check Package.swift configuration

2. **"Invalid API key" errors**
   - Solution: Verify anon key format (sb_publishable_...)
   - Check authentication token retrieval

3. **Database connection failures**
   - Solution: Verify user authentication status
   - Check PostgREST client configuration

### **Authentication Issues**
```swift
// Debug authentication status
let authService = SupabaseAuthService.shared
print("isAuthenticated: \(authService.isAuthenticated)")
print("userEmail: \(authService.userEmail ?? "none")")
print("accessToken exists: \(authService.getCurrentAccessToken() != nil)")
```

## 📊 **DATA FLOW**

### **Session Recording → Database → Display**
```
1. RecordingManager captures RR intervals
2. Session data uploaded to API (if using API flow)
3. OR: Direct database insertion (future enhancement)
4. DatabaseSessionManager queries PostgreSQL via PostgREST
5. Sessions displayed in clean card-based UI with debug info
```

## 🚀 **DEPLOYMENT CHECKLIST**

### **Pre-Build Setup**
- [ ] Verify Supabase Swift SDK installation (2.31.1)
- [ ] Configure SupabaseConfig with correct URL and keys
- [ ] Test authentication flow (signup/login)
- [ ] Verify database connectivity

### **Build Verification**
- [ ] Clean build succeeds without errors
- [ ] App launches on simulator/device
- [ ] Authentication works (signup/login)
- [ ] Sessions tab loads without errors
- [ ] Debug diagnostics show correct information

### **Production Readiness**
- [ ] Remove debug logging (if desired)
- [ ] Configure proper error handling
- [ ] Test with real user data
- [ ] Verify performance with large datasets

---

## 📚 **RELATED DOCUMENTATION**

- `ARCHITECTURE_BLUEPRINT.md` - Complete system architecture
- `DatabaseSessionManager.swift` - Direct database access implementation
- `SupabaseConfig.swift` - Hybrid authentication configuration
- API `README.md` - Backend system documentation
- `admin_db_api_control.ipynb` - Admin management tools

---

**Last Updated**: 2025-08-04  
**Version**: 5.0.0 FINAL  
**Status**: ✅ Production Ready  

