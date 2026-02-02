import SwiftUI

struct UserProfileHeader: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingAuthSettings = false
    
    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            Button(action: { showingAuthSettings = true }) {
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
                        .frame(width: 40, height: 40)
                    
                    if let user = authManager.currentUser {
                        if user.signInMethod == .apple {
                            Image(systemName: "applelogo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                if let user = authManager.currentUser {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Image(systemName: authManager.isAuthenticated ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(authManager.isAuthenticated ? .green : .orange)
                        
                        Text(authManager.isAuthenticated ? "Authenticated" : "Not Authenticated")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Text("Not signed in")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Tap to sign in")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Security indicator
            if authManager.biometricType != .none && authManager.isBiometricEnabled() {
                VStack {
                    Image(systemName: authManager.biometricType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(CortexColors.accents.neonGreen)
                    
                    Text(authManager.biometricType.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CortexColors.glass.overlay10)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(CortexColors.glass.overlay15, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingAuthSettings) {
            AuthenticationSettingsView()
        }
    }
}

#Preview {
    UserProfileHeader()
        .padding()
        .background(
            LinearGradient(
                colors: [
                    CortexColors.primary.deepSpace,
                    CortexColors.primary.darkBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}