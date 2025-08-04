import SwiftUI

struct AuthView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUpMode = false
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    
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
                
                // Error Message
                // Note: Error handling will be managed through CoreEngine events
                // TODO: Implement proper error state management through CoreEngine
                
                // Action Button
                Button(action: handleAuthAction) {
                    HStack {
                        // Loading state managed by CoreEngine
                        if false { // Placeholder - will be managed by CoreEngine state
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
        Task {
            do {
                if isSignUpMode {
                    try await coreEngine.signUp(email: email, password: password)
                } else {
                    try await coreEngine.signIn(email: email, password: password)
                }
            } catch {
                // Error is already handled in AuthService
            }
        }
    }
}

#Preview {
    AuthView()
}
