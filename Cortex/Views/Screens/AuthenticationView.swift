import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingBiometricAuth = false
    @State private var authenticationError: String?
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                Spacer()
                
                // App branding
                VStack(spacing: 24) {
                    appLogo
                    welcomeSection
                }
                
                Spacer()
                
                // Authentication options
                VStack(spacing: 20) {
                    if authManager.currentUser != nil {
                        // User is signed in, show unlock options
                        unlockSection
                    } else {
                        // No user, show sign in options
                        signInSection
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            
            // Biometric prompt overlay
            if authManager.currentUser != nil && 
               authManager.biometricType != .none && 
               authManager.isBiometricEnabled() &&
               authManager.showingAuthenticationView {
                BiometricPromptView()
                    .transition(.opacity)
            }
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(authenticationError ?? "Unknown error occurred")
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                CortexColors.primary.deepSpace,
                CortexColors.primary.darkBlue,
                CortexColors.primary.mediumBlue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var appLogo: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                CortexColors.accents.electricBlue,
                                CortexColors.accents.vibrantPurple
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: CortexColors.accents.electricBlue.opacity(0.3), radius: 20)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text("Cortex")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CortexColors.accents.electricBlue,
                            CortexColors.accents.vibrantPurple
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 12) {
            if let user = authManager.currentUser {
                Text("Welcome back,")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(user.displayName)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else {
                Text("Welcome to Cortex")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Your intelligent bookmark manager")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var signInSection: some View {
        VStack(spacing: 16) {
            Text("Sign in to sync your bookmarks across all devices")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Sign in with Apple button
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { _ in
                    // Handled by AuthenticationManager
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(12)
            
            Button("Continue as Guest") {
                createGuestUser()
            }
            .font(.headline)
            .foregroundColor(CortexColors.accents.electricBlue)
            .padding(.top, 8)
        }
    }
    
    private var unlockSection: some View {
        VStack(spacing: 20) {
            Text("Authenticate to access your bookmarks")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            if authManager.biometricType != .none && authManager.isBiometricEnabled() {
                // Biometric authentication button
                Button(action: { authenticateWithBiometrics() }) {
                    HStack(spacing: 12) {
                        Image(systemName: authManager.biometricType.iconName)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock with \(authManager.biometricType.displayName)")
                                .font(.headline)
                            Text("Quick and secure access")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                CortexColors.accents.electricBlue,
                                CortexColors.accents.vibrantPurple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            
            // Passcode authentication button
            Button(action: { authenticateWithPasscode() }) {
                HStack(spacing: 12) {
                    Image(systemName: "lock")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Device Passcode")
                            .font(.headline)
                        Text("Authenticate with your device passcode")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(CortexColors.glass.overlay15)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CortexColors.glass.overlay20, lineWidth: 1)
                )
            }
            
            // Sign out option
            Button("Sign Out") {
                authManager.signOut()
            }
            .font(.subheadline)
            .foregroundColor(.red.opacity(0.8))
            .padding(.top, 16)
        }
    }
    
    // MARK: - Actions
    
    private func authenticateWithBiometrics() {
        Task {
            let success = await authManager.authenticateWithBiometrics()
            if !success {
                await MainActor.run {
                    authenticationError = "Biometric authentication failed. Please try again."
                    showingError = true
                }
            }
        }
    }
    
    private func authenticateWithPasscode() {
        Task {
            let success = await authManager.authenticateWithDevicePasscode()
            if !success {
                await MainActor.run {
                    authenticationError = "Device authentication failed. Please try again."
                    showingError = true
                }
            }
        }
    }
    
    private func createGuestUser() {
        let guestUser = CortexUser(
            id: "guest_\(UUID().uuidString)",
            email: "",
            displayName: "Guest User",
            firstName: "Guest",
            lastName: "",
            signInMethod: .guest,
            createdAt: Date()
        )
        
        // Save guest user locally (no cloud sync)
        if let userData = try? JSONEncoder().encode(guestUser) {
            KeychainHelper.store(
                service: "io.github.Cortex.auth",
                account: "user_\(guestUser.id)",
                data: userData
            )
            
            let userIDData = guestUser.id.data(using: .utf8)!
            KeychainHelper.store(
                service: "io.github.Cortex.auth",
                account: "cortex_user_id",
                data: userIDData
            )
        }
        
        authManager.currentUser = guestUser
        authManager.isAuthenticated = true
        
        print("👤 Guest user created successfully")
    }
}

#Preview {
    AuthenticationView()
}