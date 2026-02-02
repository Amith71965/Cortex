import Foundation
import AuthenticationServices
import LocalAuthentication
import Security
import SwiftUI

/// Comprehensive authentication manager using Apple's native frameworks
@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: CortexUser?
    @Published var authenticationMethod: AuthMethod = .none
    @Published var biometricType: BiometricType = .none
    @Published var showingAuthenticationView = false
    
    private let keychainService = "io.github.Cortex.auth"
    private let userIDKey = "cortex_user_id"
    private let authTokenKey = "cortex_auth_token"
    private let biometricEnabledKey = "biometricAuthEnabled"
    
    private override init() {
        super.init()
        checkBiometricAvailability()
        loadAuthenticationState()
    }
    
    // MARK: - Authentication State Management
    
    func loadAuthenticationState() {
        // Check if user was previously authenticated
        if let savedUserID = KeychainHelper.retrieve(service: keychainService, account: userIDKey),
           let userID = String(data: savedUserID, encoding: .utf8) {
            
            // Load user from keychain
            if let userData = KeychainHelper.retrieve(service: keychainService, account: "user_\(userID)"),
               let user = try? JSONDecoder().decode(CortexUser.self, from: userData) {
                currentUser = user
                authenticationMethod = .signInWithApple
                
                // Check if biometric is enabled and available
                let biometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
                if biometricEnabled && biometricType != .none {
                    // Require biometric authentication to unlock
                    showingAuthenticationView = true
                } else {
                    isAuthenticated = true
                }
            }
        }
    }
    
    func signOut() {
        // Clear keychain data
        KeychainHelper.delete(service: keychainService, account: userIDKey)
        if let userID = currentUser?.id {
            KeychainHelper.delete(service: keychainService, account: "user_\(userID)")
            KeychainHelper.delete(service: keychainService, account: authTokenKey)
        }
        
        // Reset state
        currentUser = nil
        isAuthenticated = false
        authenticationMethod = .none
        showingAuthenticationView = false
        
        print("👋 User signed out successfully")
    }
    
    // MARK: - Sign in with Apple
    
    func startSignInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Biometric Authentication
    
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                biometricType = .opticID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
        
        print("🔐 Biometric availability: \(biometricType)")
    }
    
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        
        let reason = "Authenticate to access your bookmarks"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            await MainActor.run {
                if success {
                    isAuthenticated = true
                    showingAuthenticationView = false
                    print("✅ Biometric authentication successful")
                }
            }
            
            return success
        } catch {
            print("❌ Biometric authentication failed: \(error)")
            return false
        }
    }
    
    func authenticateWithDevicePasscode() async -> Bool {
        let context = LAContext()
        let reason = "Authenticate to access your bookmarks"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            await MainActor.run {
                if success {
                    isAuthenticated = true
                    showingAuthenticationView = false
                    print("✅ Passcode authentication successful")
                }
            }
            
            return success
        } catch {
            print("❌ Passcode authentication failed: \(error)")
            return false
        }
    }
    
    // MARK: - Settings
    
    func toggleBiometricAuthentication(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricEnabledKey)
        print("🔐 Biometric authentication \(enabled ? "enabled" : "disabled")")
    }
    
    func isBiometricEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - User Management
    
    private func saveUser(_ user: CortexUser, token: String) {
        // Save user ID
        let userIDData = user.id.data(using: .utf8)!
        KeychainHelper.store(service: keychainService, account: userIDKey, data: userIDData)
        
        // Save user data
        if let userData = try? JSONEncoder().encode(user) {
            KeychainHelper.store(service: keychainService, account: "user_\(user.id)", data: userData)
        }
        
        // Save auth token
        let tokenData = token.data(using: .utf8)!
        KeychainHelper.store(service: keychainService, account: authTokenKey, data: tokenData)
        
        currentUser = user
        authenticationMethod = .signInWithApple
        isAuthenticated = true
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            handleAppleIDCredential(appleIDCredential)
        default:
            break
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Sign in with Apple failed: \(error)")
    }
    
    private func handleAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user
        let email = credential.email ?? ""
        let fullName = credential.fullName
        
        let firstName = fullName?.givenName ?? ""
        let lastName = fullName?.familyName ?? ""
        let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        let user = CortexUser(
            id: userID,
            email: email,
            displayName: displayName.isEmpty ? "Apple User" : displayName,
            firstName: firstName,
            lastName: lastName,
            signInMethod: .apple,
            createdAt: Date()
        )
        
        // Generate a simple token (in production, this would come from your backend)
        let token = "apple_\(userID)_\(Date().timeIntervalSince1970)"
        
        saveUser(user, token: token)
        
        print("✅ Sign in with Apple successful")
        print("   - User ID: \(userID)")
        print("   - Email: \(email)")
        print("   - Name: \(displayName)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Supporting Types

struct CortexUser: Codable {
    let id: String
    let email: String
    let displayName: String
    let firstName: String
    let lastName: String
    let signInMethod: SignInMethod
    let createdAt: Date
    
    enum SignInMethod: String, Codable {
        case apple = "apple"
        case guest = "guest"
    }
}

enum AuthMethod {
    case none
    case signInWithApple
    case biometric
    case passcode
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none: return "lock"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static func store(service: String, account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain store failed: \(status)")
        }
    }
    
    static func retrieve(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            return nil
        }
    }
    
    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}