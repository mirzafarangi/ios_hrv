import SwiftUI

struct ProfileTabView: View {
    @StateObject private var authService = SupabaseAuthService.shared
    @State private var showingSignOutAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // User Information Card
                VStack(spacing: 0) {
                    // Card Header
                    HStack {
                        Text("User Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "person.badge.key.fill")
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    
                    // Card Content
                    VStack(spacing: 16) {
                        // Email
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(authService.userEmail ?? "Not available")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                        }
                        
                        Divider()
                        
                        // User ID
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("User ID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(authService.userId ?? "Not available")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: copyUserId) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Divider()
                        
                        // Authentication Status
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(authService.isAuthenticated ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(authService.isAuthenticated ? "Authenticated" : "Not Authenticated")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 20)
                
                // Actions Section
                VStack(spacing: 12) {
                    // Sign Out Button
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    
                    // App Info
                    VStack(spacing: 8) {
                        Text("HRV Monitor v1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Built with clean architecture")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                    showingSuccessAlert = true
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                authService.clearMessages()
            }
        } message: {
            Text(authService.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                authService.clearMessages()
            }
        } message: {
            Text(authService.successMessage ?? "Operation completed successfully")
        }
        .onChange(of: authService.errorMessage) {
            if authService.errorMessage != nil {
                showingErrorAlert = true
            }
        }
        .onChange(of: authService.successMessage) {
            if authService.successMessage != nil {
                showingSuccessAlert = true
            }
        }
    }
    
    private func copyUserId() {
        if let userId = authService.userId {
            UIPasteboard.general.string = userId
            // Could add a toast notification here
            print("📋 User ID copied to clipboard: \(userId)")
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(SupabaseAuthService.shared)
}
