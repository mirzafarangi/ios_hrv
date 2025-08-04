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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("HRV Monitor")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(isSignUpMode ? "Create your account" : "Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Confirm Password (Sign Up only)
                    if isSignUpMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Confirm Password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField("Confirm your password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Error Message Display
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Success Message Display
                if let successMessage = authService.successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Action Button
                Button(action: handleAuthAction) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        
                        Text(isSignUpMode ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid)
                .padding(.horizontal, 20)
                
                // Toggle Mode
                Button(action: {
                    isSignUpMode.toggle()
                    // Error state managed by CoreEngine
                }) {
                    Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Forgot Password
                if !isSignUpMode {
                    Button("Forgot Password?") {
                        showingResetPassword = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                Spacer()
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
                    print("Sign up attempt for: \(email)")
                    try await coreEngine.signUp(email: email, password: password)
                } else {
                    // Handle sign in through CoreEngine
                    print("Sign in attempt for: \(email)")
                    try await coreEngine.signIn(email: email, password: password)
                }
            } catch {
                print("Authentication error: \(error)")
                // Error is already handled by authService.errorMessage
            }
        }
    }
}

#Preview {
    AuthView()
}
