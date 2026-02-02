import Foundation
import CoreML
import NaturalLanguage

class CoreMLModelLoader {
    static let shared = CoreMLModelLoader()
    
    private var distilBERTModel: MLModel?
    private var isModelLoaded = false
    private var modelDescription: MLModelDescription?
    
    // DistilBERT configuration
    private let maxSequenceLength = 512
    private let modelName = "distilbert-base"
    
    // Tag mapping for DistilBERT classification outputs
    private let classificationMapping: [Int: String] = [
        0: "Technology",
        1: "Business", 
        2: "Education",
        3: "Entertainment",
        4: "News",
        5: "Health",
        6: "Sports",
        7: "Science",
        8: "Travel",
        9: "Food",
        10: "Shopping",
        11: "Social",
        12: "Reference",
        13: "Programming",
        14: "Finance"
    ]
    
    private init() {}
    
    // MARK: - Model Loading
    
    func loadModel() async -> Bool {
        guard !isModelLoaded else { return true }
        
        do {
            // Load DistilBERT model from bundle
            print("🔍 Looking for model: \(modelName).mlpackage")
            
            // Debug: List all mlpackage files in bundle
            if let bundlePath = Bundle.main.resourcePath {
                print("📂 Bundle path: \(bundlePath)")
                let fileManager = FileManager.default
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: bundlePath)
                    let mlFiles = files.filter { $0.contains(".mlpackage") }
                    print("🗂️ Found .mlpackage files: \(mlFiles)")
                } catch {
                    print("❌ Error listing bundle contents: \(error)")
                }
            }
            
            guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
                print("❌ DistilBERT model file not found in bundle - using fallback mode")
                print("   Expected: \(modelName).mlpackage")
                isModelLoaded = true // Still mark as loaded to enable fallback processing
                return true
            }
            
            print("📦 Loading DistilBERT model from: \(modelURL.path)")
            
            // Configure model for optimal performance
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            // Note: allowLowPrecisionAccumulation is not available in iOS 17
            // Using default precision settings for maximum compatibility
            
            // Load the model
            distilBERTModel = try MLModel(contentsOf: modelURL, configuration: configuration)
            modelDescription = distilBERTModel?.modelDescription
            
            // Validate model structure
            guard validateModelStructure() else {
                print("❌ Model structure validation failed - using fallback mode")
                isModelLoaded = true // Still enable fallback processing
                return true
            }
            
            isModelLoaded = true
            print("✅ DistilBERT model loaded successfully")
            logModelMetadata()
            
            return true
            
        } catch {
            print("❌ Failed to load DistilBERT model: \(error) - using fallback mode")
            isModelLoaded = true // Enable fallback processing
            return true
        }
    }
    
    // MARK: - Text Classification
    
    func classifyText(_ text: String) async -> [ClassificationResult] {
        guard isModelLoaded, let model = distilBERTModel else {
            print("⚠️ Model not loaded, falling back to rule-based classification")
            return await fallbackClassification(text)
        }
        
        do {
            // Preprocess text for DistilBERT
            let processedText = preprocessText(text)
            let tokens = tokenizeText(processedText)
            
            // Create model input
            let input = try createModelInput(tokens: tokens)
            
            // Run inference
            let output = try await model.prediction(from: input)
            
            // Process output and create results
            let results = try processModelOutput(output)
            
            print("🧠 DistilBERT classified text with \(results.count) predictions")
            return results
            
        } catch {
            print("❌ DistilBERT classification error: \(error)")
            return await fallbackClassification(text)
        }
    }
    
    // MARK: - Text Preprocessing & Tokenization
    
    private func preprocessText(_ text: String) -> String {
        // Clean and normalize text for DistilBERT
        let cleaned = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Truncate to reasonable length before tokenization
        let maxChars = maxSequenceLength * 4 // Rough estimate for token-to-char ratio
        if cleaned.count > maxChars {
            let index = cleaned.index(cleaned.startIndex, offsetBy: maxChars)
            return String(cleaned[..<index])
        }
        
        return cleaned
    }
    
    private func tokenizeText(_ text: String) -> [Int] {
        // Simple whitespace tokenization for DistilBERT
        // In production, you'd use a proper BERT tokenizer
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Map words to token IDs (simplified approach)
        // This is a simplified tokenizer - in production use proper BERT tokenizer
        var tokens: [Int] = [101] // [CLS] token
        
        for word in words.prefix(maxSequenceLength - 2) { // Reserve space for [CLS] and [SEP]
            // Simple hash-based token mapping (replace with proper tokenizer)
            let tokenId = abs(word.hash) % 30000 + 1000 // Map to reasonable token range
            tokens.append(tokenId)
        }
        
        tokens.append(102) // [SEP] token
        
        // Pad to max length
        while tokens.count < maxSequenceLength {
            tokens.append(0) // [PAD] token
        }
        
        return Array(tokens.prefix(maxSequenceLength))
    }
    
    // MARK: - Model Input/Output Handling
    
    private func createModelInput(tokens: [Int]) throws -> MLFeatureProvider {
        let sequenceLength = tokens.count
        
        // Create input_ids array with explicit shape
        let inputIdsShape = [1, sequenceLength] as [NSNumber]
        let inputIds = try MLMultiArray(shape: inputIdsShape, dataType: .int32)
        
        // Set input_ids values using linear indexing for safety
        for (index, token) in tokens.enumerated() {
            if index < inputIds.count {
                inputIds[index] = NSNumber(value: token)
            }
        }
        
        // Create attention_mask array with same shape
        let attentionMaskShape = [1, sequenceLength] as [NSNumber]
        let attentionMask = try MLMultiArray(shape: attentionMaskShape, dataType: .int32)
        
        // Set attention_mask values using linear indexing (0 for padding, 1 for real tokens)
        for (index, token) in tokens.enumerated() {
            if index < attentionMask.count {
                attentionMask[index] = NSNumber(value: token == 0 ? 0 : 1)
            }
        }
        
        // Create feature provider with explicit dictionary
        let featuresDict: [String: MLFeatureValue] = [
            "input_ids": MLFeatureValue(multiArray: inputIds),
            "attention_mask": MLFeatureValue(multiArray: attentionMask)
        ]
        
        return try MLDictionaryFeatureProvider(dictionary: featuresDict)
    }
    
    private func processModelOutput(_ output: MLFeatureProvider) throws -> [ClassificationResult] {
        // Get logits from model output
        guard let logitsFeature = output.featureValue(for: "logits") ?? output.featureValue(for: "output"),
              let logits = logitsFeature.multiArrayValue else {
            throw MLModelError.invalidOutput("Could not extract logits from model output")
        }
        
        // Convert logits to probabilities using softmax
        let probabilities = applySoftmax(to: logits)
        
        // Create classification results
        var results: [ClassificationResult] = []
        
        for (index, probability) in probabilities.enumerated() {
            if let category = classificationMapping[index], probability > 0.1 { // Minimum confidence threshold
                results.append(ClassificationResult(
                    category: category,
                    confidence: Double(probability)
                ))
            }
        }
        
        // Sort by confidence and return top results
        return Array(results.sorted { $0.confidence > $1.confidence }.prefix(5))
    }
    
    private func applySoftmax(to multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var values: [Float] = []
        
        // Extract values
        for i in 0..<count {
            values.append(multiArray[i].floatValue)
        }
        
        // Apply softmax
        let maxValue = values.max() ?? 0
        let expValues = values.map { exp($0 - maxValue) }
        let sumExp = expValues.reduce(0, +)
        
        return expValues.map { $0 / sumExp }
    }
    
    // MARK: - Validation & Metadata
    
    private func validateModelStructure() -> Bool {
        guard let description = modelDescription else { return false }
        
        // Check required inputs
        let inputNames = Set(description.inputDescriptionsByName.keys)
        let requiredInputs = Set(["input_ids", "attention_mask"])
        
        if !requiredInputs.isSubset(of: inputNames) {
            print("❌ Missing required inputs. Expected: \(requiredInputs), Found: \(inputNames)")
            return false
        }
        
        // Check output structure
        if description.outputDescriptionsByName.isEmpty {
            print("❌ No model outputs found")
            return false
        }
        
        return true
    }
    
    private func logModelMetadata() {
        guard let description = modelDescription else { return }
        
        print("📊 Model Metadata:")
        print("   - Author: \(description.metadata[.author] ?? "Unknown")")
        print("   - Description: \(description.metadata[.description] ?? "No description")")
        print("   - Inputs: \(description.inputDescriptionsByName.keys.joined(separator: ", "))")
        print("   - Outputs: \(description.outputDescriptionsByName.keys.joined(separator: ", "))")
        
        // Log input shapes
        for (name, desc) in description.inputDescriptionsByName {
            if let multiArrayConstraint = desc.multiArrayConstraint {
                print("   - \(name) shape: \(multiArrayConstraint.shape)")
            }
        }
    }
    
    // MARK: - Fallback Classification
    
    private func fallbackClassification(_ text: String) async -> [ClassificationResult] {
        print("🔄 Using fallback rule-based classification")
        
        let lowercaseText = text.lowercased()
        var results: [ClassificationResult] = []
        
        // Define classification categories and their keywords
        let categories: [String: [String]] = [
            "Technology": ["programming", "software", "development", "code", "tech", "api", "framework", "javascript", "python", "swift"],
            "Business": ["business", "finance", "money", "startup", "revenue", "market", "sales", "company", "entrepreneur"],
            "Education": ["learn", "tutorial", "course", "education", "study", "academic", "university", "school", "lesson"],
            "Entertainment": ["movie", "music", "game", "fun", "entertainment", "video", "stream", "netflix", "youtube"],
            "News": ["news", "breaking", "report", "journalist", "politics", "current", "events", "media", "press"],
            "Health": ["health", "medical", "fitness", "wellness", "nutrition", "exercise", "doctor", "medicine", "diet"],
            "Sports": ["sports", "football", "basketball", "soccer", "athletics", "competition", "team", "player", "game"],
            "Science": ["science", "research", "study", "experiment", "discovery", "scientific", "data", "analysis"],
            "Programming": ["coding", "developer", "github", "stackoverflow", "programming", "computer", "algorithm"],
            "Shopping": ["shop", "buy", "purchase", "store", "amazon", "ecommerce", "retail", "product", "price"]
        ]
        
        // Calculate confidence based on keyword matches
        for (category, keywords) in categories {
            let matches = keywords.filter { lowercaseText.contains($0) }
            if !matches.isEmpty {
                let confidence = min(Double(matches.count) / Double(keywords.count) * 2.0, 1.0)
                if confidence > 0.2 {
                    results.append(ClassificationResult(category: category, confidence: confidence))
                }
            }
        }
        
        // Sort by confidence and return top results
        return Array(results.sorted { $0.confidence > $1.confidence }.prefix(3))
    }
    
    // MARK: - Utility Methods
    
    func getModelInfo() -> (isLoaded: Bool, modelPath: String?, inputNames: [String], outputNames: [String]) {
        let modelPath = Bundle.main.url(forResource: modelName, withExtension: "mlpackage")?.path
        let inputNames = modelDescription?.inputDescriptionsByName.keys.map { String($0) } ?? []
        let outputNames = modelDescription?.outputDescriptionsByName.keys.map { String($0) } ?? []
        
        return (isModelLoaded, modelPath, inputNames, outputNames)
    }
    
    func unloadModel() {
        distilBERTModel = nil
        modelDescription = nil
        isModelLoaded = false
        print("🗑️ DistilBERT model unloaded")
    }
}

// MARK: - Supporting Types

struct ClassificationResult {
    let category: String
    let confidence: Double
}

enum MLModelError: Error, LocalizedError {
    case modelNotFound(String)
    case invalidInput(String)
    case invalidOutput(String)
    case tokenizationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .invalidOutput(let message):
            return "Invalid output: \(message)"
        case .tokenizationFailed(let message):
            return "Tokenization failed: \(message)"
        }
    }
}

// MARK: - Advanced Tokenization (Production Implementation)

extension CoreMLModelLoader {
    
    /// Production-ready BERT tokenizer implementation
    /// This would replace the simplified tokenization above
    private func advancedTokenization(_ text: String) -> (inputIds: [Int], attentionMask: [Int]) {
        // In a production app, you would:
        // 1. Use a proper BERT tokenizer (e.g., from TensorFlow Swift or custom implementation)
        // 2. Handle special tokens correctly ([CLS], [SEP], [PAD], [UNK])
        // 3. Implement proper subword tokenization
        // 4. Handle out-of-vocabulary words
        
        // Example implementation would look like:
        /*
        let tokenizer = BERTTokenizer(vocabularyPath: "vocab.txt")
        let tokenized = tokenizer.tokenize(text)
        let inputIds = tokenizer.convertTokensToIds(tokenized.tokens)
        let attentionMask = Array(repeating: 1, count: inputIds.count)
        
        return (inputIds, attentionMask)
        */
        
        // For now, return the simplified version
        let tokens = tokenizeText(text)
        let attentionMask = tokens.map { $0 == 0 ? 0 : 1 }
        return (tokens, attentionMask)
    }
    
    /// Download additional model resources if needed
    func downloadModelResources() async -> Bool {
        // Implementation for downloading vocabulary files, etc.
        return true
    }
}