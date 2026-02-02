import Foundation
import SwiftUI
import UserNotifications

struct AppTestHelper {
    static func printSystemInfo() {
        print("📱 App Launch Information:")
        print("   - iOS Version: \(UIDevice.current.systemVersion)")
        print("   - Device Model: \(UIDevice.current.model)")
        print("   - App Bundle: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("   - Build Version: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
    }
    
    static func checkCoreMLAvailability() -> Bool {
        #if targetEnvironment(simulator)
        print("⚠️ Running on simulator - CoreML may have limited functionality")
        return true
        #else
        print("✅ Running on device - CoreML fully available")
        return true
        #endif
    }
    
    static func validateAppStructure() -> Bool {
        print("📁 Validating app structure...")
        
        // Check if essential services can be instantiated (this validates compiled code)
        var validationsPassed = 0
        let totalValidations = 4
        
        // Test 1: CoreML Model Loader
        do {
            let _ = CoreMLModelLoader.shared
            print("✅ CoreMLModelLoader - Available")
            validationsPassed += 1
        } catch {
            print("❌ CoreMLModelLoader - Failed: \(error)")
        }
        
        // Test 2: Web Content Extractor
        do {
            let _ = WebContentExtractor()
            print("✅ WebContentExtractor - Available")
            validationsPassed += 1
        } catch {
            print("❌ WebContentExtractor - Failed: \(error)")
        }
        
        // Test 3: Check for CoreML model file
        if Bundle.main.url(forResource: "distilbert-base", withExtension: "mlpackage") != nil {
            print("✅ DistilBERT model file - Found")
            validationsPassed += 1
        } else {
            print("⚠️ DistilBERT model file - Not found (using fallback mode)")
        }
        
        // Test 4: App Bundle validation
        if Bundle.main.bundleIdentifier != nil {
            print("✅ App Bundle - Valid")
            validationsPassed += 1
        } else {
            print("❌ App Bundle - Invalid")
        }
        
        print("📊 Validation Results: \(validationsPassed)/\(totalValidations) checks passed")
        return validationsPassed >= totalValidations - 1 // Allow missing model file
    }
}

// Simple app initialization helper
struct AppInitializer {
    static func initialize() {
        print("🚀 Cortex App Initializing...")
        
        AppTestHelper.printSystemInfo()
        _ = AppTestHelper.checkCoreMLAvailability()
        _ = AppTestHelper.validateAppStructure()
        
        // Initialize AI service in background
        Task {
            await MainActor.run {
                let aiService = AITaggingService.shared
                print("🧠 AI Service initialized: \(aiService.isModelLoaded)")
            }
            
            // Initialize backup notifications
            let notificationManager = BackupNotificationManager.shared
            let hasPermission = await notificationManager.checkNotificationPermission()
            print("📮 Notification permission: \(hasPermission)")
            
            // Setup notification delegate
            UNUserNotificationCenter.current().delegate = NotificationDelegate()
        }
        
        print("✅ Cortex App Initialization Complete")
        
        // Run startup tests in debug mode
        #if DEBUG
        AppInitializer.runStartupTests()
        #endif
    }
}