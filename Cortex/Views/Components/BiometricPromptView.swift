import SwiftUI

struct BiometricPromptView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isAuthenticating = false
    @State private var authenticationFailed = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Biometric icon
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
                            .frame(width: 100, height: 100)
                            .scaleEffect(isAuthenticating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAuthenticating)
                        
                        Image(systemName: authManager.biometricType.iconName)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("Unlock Cortex")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Use \(authManager.biometricType.displayName) to access your bookmarks")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    // Primary biometric button
                    Button(action: { authenticateWithBiometrics() }) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: authManager.biometricType.iconName)
                                    .font(.title3)
                            }
                            
                            Text(isAuthenticating ? "Authenticating..." : "Use \(authManager.biometricType.displayName)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
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
                    .disabled(isAuthenticating)
                    
                    // Alternative passcode button
                    Button(action: { authenticateWithPasscode() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key")
                                .font(.subheadline)
                            Text("Use Passcode Instead")
                                .font(.subheadline)
                        }
                        .foregroundColor(CortexColors.accents.electricBlue)
                    }
                    .disabled(isAuthenticating)
                }
                .padding(.horizontal, 32)
                
                if authenticationFailed {
                    Text("Authentication failed. Please try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear {
            // Auto-trigger biometric authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticateWithBiometrics()
            }
        }
    }
    
    private func authenticateWithBiometrics() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        authenticationFailed = false
        
        Task {
            let success = await authManager.authenticateWithBiometrics()
            
            await MainActor.run {
                isAuthenticating = false
                if !success {
                    authenticationFailed = true
                    // Auto-hide error after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        authenticationFailed = false
                    }
                }
            }
        }
    }
    
    private func authenticateWithPasscode() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        authenticationFailed = false
        
        Task {
            let success = await authManager.authenticateWithDevicePasscode()
            
            await MainActor.run {
                isAuthenticating = false
                if !success {
                    authenticationFailed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        authenticationFailed = false
                    }
                }
            }
        }
    }
}

#Preview {
    BiometricPromptView()
}