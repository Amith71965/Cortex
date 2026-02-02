import Foundation
import SwiftUI

struct StartupTest {
    static func runTests() {
        print("🧪 Running startup tests...")
        
        // Test 1: AI Service initialization (run on main actor)
        Task {
            await MainActor.run {
                let aiService = AITaggingService.shared
                print("✅ AITaggingService initialized successfully")
                print("   - Model loaded: \(aiService.isModelLoaded)")
                print("   - Processing: \(aiService.isProcessing)")
            }
        }
        
        // Test 2: CoreML Loader
        let loader = CoreMLModelLoader.shared
        let info = loader.getModelInfo()
        print("✅ CoreMLModelLoader initialized successfully")
        print("   - Model loaded: \(info.isLoaded)")
        print("   - Model path exists: \(info.modelPath != nil)")
        
        // Test 3: Web Content Extractor
        let _ = WebContentExtractor()
        print("✅ WebContentExtractor initialized successfully")
        
        // Test 4: Sample model classification
        Task {
            let loader = CoreMLModelLoader.shared
            
            // First try to load the model
            let modelLoaded = await loader.loadModel()
            print("🔄 Model loading result: \(modelLoaded)")
            
            let sampleText = "This is a technology article about programming and software development"
            let results = await loader.classifyText(sampleText)
            print("✅ Sample classification completed with \(results.count) results")
            
            if results.isEmpty {
                print("⚠️ No classification results - check model file")
            } else {
                for result in results {
                    print("   - \(result.category): \(String(format: "%.1f%%", result.confidence * 100))")
                }
            }
        }
        
        print("🧪 Startup tests completed")
    }
}

// Extension to make it easier to call from app initialization
extension AppInitializer {
    static func runStartupTests() {
        #if DEBUG
        StartupTest.runTests()
        #endif
    }
}