import SwiftUI
import AuthenticationServices

struct AuthenticationSettingsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var biometricEnabled = false
    @State private var showingSignOutAlert = false
    @State private var showingAccountDeletion = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if let user = authManager.currentUser {
                        accountSection(user: user)
                        securitySection
                        dangerZoneSection
                    } else {
                        notSignedInSection
                    }
                }
                .padding()
            }
            .navigationTitle("Account & Security")
            .navigationBarTitleDisplayMode(.large)
            .background(backgroundGradient)
        }
        .onAppear {
            loadSettings()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to authenticate again to access your bookmarks.")
        }
        .alert("Delete Account", isPresented: $showingAccountDeletion) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CortexColors.accents.electricBlue,
                            CortexColors.accents.vibrantPurple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Account & Security")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Manage your authentication settings")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func accountSection(user: CortexUser) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.electricBlue)
                    
                    Text("Account Information")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    AccountInfoRow(
                        title: "Name",
                        value: user.displayName,
                        icon: "person"
                    )
                    
                    if !user.email.isEmpty {
                        AccountInfoRow(
                            title: "Email",
                            value: user.email,
                            icon: "envelope"
                        )
                    }
                    
                    AccountInfoRow(
                        title: "Sign-in Method",
                        value: user.signInMethod == .apple ? "Sign in with Apple" : "Guest Account",
                        icon: user.signInMethod == .apple ? "applelogo" : "person.crop.circle"
                    )
                    
                    AccountInfoRow(
                        title: "Member Since",
                        value: user.createdAt.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }
            }
            .padding()
        }
    }
    
    private var securitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "shield.fill")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.neonGreen)
                    
                    Text("Security Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 16) {
                    if authManager.biometricType != .none {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(authManager.biometricType.displayName) Authentication")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Text("Use \(authManager.biometricType.displayName) to unlock the app")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $biometricEnabled)
                                .tint(CortexColors.accents.neonGreen)
                                .onChange(of: biometricEnabled) { _, newValue in
                                    authManager.toggleBiometricAuthentication(newValue)
                                }
                        }
                        
                        Divider()
                            .background(.white.opacity(0.2))
                    }
                    
                    SecurityFeatureRow(
                        title: "Keychain Storage",
                        description: "Authentication data stored securely",
                        icon: "key.fill",
                        status: .enabled
                    )
                    
                    SecurityFeatureRow(
                        title: "iCloud Sync",
                        description: "Data synced with end-to-end encryption",
                        icon: "icloud.fill",
                        status: authManager.currentUser?.signInMethod == .apple ? .enabled : .disabled
                    )
                    
                    SecurityFeatureRow(
                        title: "Local Authentication",
                        description: "Device-based security verification",
                        icon: "lock.fill",
                        status: .enabled
                    )
                }
            }
            .padding()
        }
    }
    
    private var dangerZoneSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    Button(action: { showingSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Sign Out")
                            Spacer()
                        }
                        .foregroundColor(.orange)
                        .padding()
                        .background(.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showingAccountDeletion = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Account")
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
    
    private var notSignedInSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.4))
                
                VStack(spacing: 8) {
                    Text("Not Signed In")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Sign in to sync your bookmarks across devices and enable additional security features")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Button("Sign In") {
                    authManager.showingAuthenticationView = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(CortexColors.accents.electricBlue)
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                CortexColors.primary.deepSpace,
                CortexColors.primary.darkBlue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        biometricEnabled = authManager.isBiometricEnabled()
    }
    
    private func deleteAccount() {
        // In a real app, this would make an API call to delete the account
        authManager.signOut()
        print("🗑️ Account deleted (local data cleared)")
    }
}

// MARK: - Supporting Views

struct AccountInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(CortexColors.accents.electricBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
}

struct SecurityFeatureRow: View {
    let title: String
    let description: String
    let icon: String
    let status: SecurityStatus
    
    enum SecurityStatus {
        case enabled, disabled, warning
        
        var color: Color {
            switch self {
            case .enabled: return .green
            case .disabled: return .red
            case .warning: return .orange
            }
        }
        
        var iconName: String {
            switch self {
            case .enabled: return "checkmark.circle.fill"
            case .disabled: return "xmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(CortexColors.accents.electricBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: status.iconName)
                .font(.subheadline)
                .foregroundColor(status.color)
        }
    }
}

#Preview {
    AuthenticationSettingsView()
}