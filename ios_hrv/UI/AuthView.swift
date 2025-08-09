import SwiftUI

struct AuthView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @StateObject private var authService = SupabaseAuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUpMode = false
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light academic background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Minimal header
                    VStack(spacing: 20) {
                        Text("LUMENIS")
                            .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.black.opacity(0.8))
                            .tracking(6)
                        
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 0.5)
                            .frame(maxWidth: 120)
                        
                        Text(isSignUpMode ? "INITIALIZE" : "AUTHENTICATE")
                            .font(.system(size: 12, weight: .light, design: .monospaced))
                            .foregroundColor(.black.opacity(0.5))
                            .tracking(2)
                    }
                    .padding(.top, 60)
                
                    // Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IDENTIFIER")
                                .font(.system(size: 10, weight: .light, design: .monospaced))
                                .foregroundColor(.black.opacity(0.5))
                                .tracking(1)
                            
                            HStack {
                                Text("@")
                                    .font(.system(size: 14, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                
                                TextField("email", text: $email)
                                    .font(.system(size: 14, design: .monospaced))
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(4)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CREDENTIAL")
                                .font(.system(size: 10, weight: .light, design: .monospaced))
                                .foregroundColor(.black.opacity(0.5))
                                .tracking(1)
                            
                            HStack {
                                Text("*")
                                    .font(.system(size: 14, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                
                                SecureField("password", text: $password)
                                    .font(.system(size: 14, design: .monospaced))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(4)
                        }
                        
                        // Confirm Password (Sign Up only)
                        if isSignUpMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("VERIFY")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.5))
                                    .tracking(1)
                                
                                HStack {
                                    Text("*")
                                        .font(.system(size: 14, weight: .light, design: .monospaced))
                                        .foregroundColor(.black.opacity(0.4))
                                    
                                    SecureField("confirm", text: $confirmPassword)
                                        .font(.system(size: 14, design: .monospaced))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                
                    // Debug Console - Enhanced error/success messaging
                    VStack(spacing: 8) {
                        if let errorMessage = authService.errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("ERROR")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.red)
                                        .tracking(1)
                                    
                                    Text(getErrorCode(from: errorMessage))
                                        .font(.system(size: 10, weight: .light, design: .monospaced))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                
                                Text(errorMessage)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        
                        if let successMessage = authService.successMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("SUCCESS")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.green)
                                        .tracking(1)
                                    
                                    Text("200")
                                        .font(.system(size: 10, weight: .light, design: .monospaced))
                                        .foregroundColor(.green.opacity(0.8))
                                }
                                
                                Text(successMessage)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.05))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 20)
                    
                    // Action Button
                    Button(action: handleAuthAction) {
                        HStack(spacing: 8) {
                            if authService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text(isSignUpMode ? "INITIALIZE" : "CONNECT")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .tracking(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isFormValid ? Color.black.opacity(0.8) : Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 20)
                    
                    // Mode Toggle
                    VStack(spacing: 12) {
                        Button(action: {
                            isSignUpMode.toggle()
                            authService.clearMessages()
                        }) {
                            Text(isSignUpMode ? "EXISTING USER" : "NEW USER")
                                .font(.system(size: 10, weight: .light, design: .monospaced))
                                .foregroundColor(.black.opacity(0.6))
                                .tracking(1)
                                .underline()
                        }
                        
                        // Forgot Password
                        if !isSignUpMode {
                            Button(action: {
                                showingResetPassword = true
                            }) {
                                Text("RESET CREDENTIAL")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                    .tracking(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Subtle phi signature at bottom
                    Text("φ")
                        .font(.system(size: 16, weight: .ultraLight, design: .serif))
                        .foregroundColor(.black.opacity(0.05))
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Reset Password", isPresented: $showingResetPassword) {
            TextField("Email", text: $resetEmail)
            Button("Send Reset Email") {
                Task {
                    try? await coreEngine.resetPassword(email: resetEmail)
                    resetEmail = ""
                }
            }
            Button("Cancel", role: .cancel) {
                resetEmail = ""
            }
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
    }
    
    private var isFormValid: Bool {
        if isSignUpMode {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleAuthAction() {
        // Clear any previous messages
        authService.clearMessages()
        
        Task {
            do {
                if isSignUpMode {
                    // Handle sign up through CoreEngine
                    print("[LUMENIS] Initialize attempt: \(email)")
                    try await coreEngine.signUp(email: email, password: password)
                } else {
                    // Handle sign in through CoreEngine
                    print("[LUMENIS] Connect attempt: \(email)")
                    try await coreEngine.signIn(email: email, password: password)
                }
            } catch {
                print("[LUMENIS] Auth error: \(error)")
                // Error is already handled by authService.errorMessage
            }
        }
    }
    
    private func getErrorCode(from message: String) -> String {
        // Extract error codes from common auth errors
        if message.contains("Invalid login") || message.contains("Invalid email or password") {
            return "401"
        } else if message.contains("User already registered") || message.contains("already exists") {
            return "409"
        } else if message.contains("Password should be at least") || message.contains("validation") {
            return "422"
        } else if message.contains("Network") || message.contains("connection") {
            return "503"
        } else if message.contains("rate limit") || message.contains("too many") {
            return "429"
        } else if message.contains("forbidden") || message.contains("unauthorized") {
            return "403"
        } else if message.contains("not found") {
            return "404"
        } else {
            return "500"
        }
    }
}

#Preview {
    AuthView()
}
