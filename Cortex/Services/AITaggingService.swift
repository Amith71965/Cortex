import Foundation
import CoreML
import NaturalLanguage
import SwiftData

@MainActor
class AITaggingService: ObservableObject {
    static let shared = AITaggingService()
    
    private var model: MLModel?
    private let cache = AITaggingCache()
    private let queue = DispatchQueue(label: "ai.tagging.queue", qos: .utility)
    private let webContentExtractor = WebContentExtractor()
    private let coreMLLoader = CoreMLModelLoader.shared
    
    @Published var isModelLoaded = false
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    
    // Predefined categories for web content classification
    private let categoryMappings: [String: [String]] = [
        "Technology": ["technology", "programming", "software", "development", "tech", "coding", "engineering"],
        "Business": ["business", "finance", "money", "marketing", "startup", "entrepreneur", "corporate"],
        "Education": ["education", "learning", "course", "tutorial", "academic", "university", "study"],
        "Entertainment": ["entertainment", "movies", "music", "games", "fun", "humor", "celebrity"],
        "News": ["news", "politics", "current events", "breaking", "journalism", "media"],
        "Health": ["health", "medical", "fitness", "wellness", "nutrition", "healthcare", "medicine"],
        "Sports": ["sports", "football", "basketball", "soccer", "athletics", "fitness", "competition"],
        "Travel": ["travel", "vacation", "tourism", "destination", "trip", "adventure", "places"],
        "Food": ["food", "cooking", "recipe", "restaurant", "cuisine", "culinary", "dining"],
        "Shopping": ["shopping", "ecommerce", "retail", "product", "buy", "store", "marketplace"],
        "Social": ["social", "community", "networking", "friends", "communication", "forum"],
        "Reference": ["reference", "documentation", "wiki", "guide", "manual", "help", "information"]
    ]
    
    private init() {
        loadModel()
    }
    
    // MARK: - Model Loading
    
    private func loadModel() {
        Task {
            let success = await coreMLLoader.loadModel()
            
            await MainActor.run {
                self.isModelLoaded = success
            }
            
            if !success {
                print("Failed to load CoreML model, falling back to NaturalLanguage framework")
                await MainActor.run {
                    self.isModelLoaded = true // Still allow processing with NLP fallback
                }
            }
        }
    }
    
    // MARK: - Public API
    
    func processBookmark(_ bookmark: Bookmark, modelContext: ModelContext) async {
        guard isModelLoaded else { return }
        
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
        }
        
        // Extract web content
        await MainActor.run { processingProgress = 0.2 }
        let content = await webContentExtractor.extractContent(from: bookmark.url)
        
        // Check cache first
        await MainActor.run { processingProgress = 0.4 }
        let cacheKey = generateCacheKey(for: bookmark)
        if let cachedTags = cache.getCachedTags(for: cacheKey) {
            await updateBookmarkWithTags(bookmark, tags: cachedTags, modelContext: modelContext)
            await MainActor.run {
                isProcessing = false
                processingProgress = 1.0
            }
            return
        }
        
        // Generate tags using AI
        await MainActor.run { processingProgress = 0.6 }
        let aiTags = await generateTags(for: content, bookmark: bookmark)
        
        // Cache results
        await MainActor.run { processingProgress = 0.8 }
        cache.cacheTags(aiTags, for: cacheKey)
        
        // Update bookmark
        await updateBookmarkWithTags(bookmark, tags: aiTags, modelContext: modelContext)
        
        await MainActor.run {
            isProcessing = false
            processingProgress = 1.0
        }
    }
    
    func processMultipleBookmarks(_ bookmarks: [Bookmark], modelContext: ModelContext) async {
        guard isModelLoaded, !bookmarks.isEmpty else { return }
        
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
        }
        
        let unprocessedBookmarks = bookmarks.filter { !$0.isProcessed }
        let totalBookmarks = unprocessedBookmarks.count
        
        guard totalBookmarks > 0 else {
            await MainActor.run {
                isProcessing = false
                processingProgress = 1.0
            }
            return
        }
        
        print("🚀 Starting batch processing of \(totalBookmarks) bookmarks")
        
        // Process bookmarks in batches for better performance and memory management
        let batchSize = 5
        let batches = unprocessedBookmarks.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            print("📦 Processing batch \(batchIndex + 1)/\(batches.count)")
            
            // Process batch items concurrently (but limit concurrency)
            await withTaskGroup(of: Void.self) { group in
                for bookmark in batch {
                    group.addTask {
                        await self.processBookmarkSafely(bookmark, modelContext: modelContext)
                    }
                }
            }
            
            // Update progress after each batch
            let processedCount = (batchIndex + 1) * batchSize
            let progress = min(Double(processedCount) / Double(totalBookmarks), 1.0)
            
            await MainActor.run {
                processingProgress = progress
            }
            
            // Small delay between batches to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        await MainActor.run {
            isProcessing = false
            processingProgress = 1.0
        }
        
        print("✅ Completed batch processing of \(totalBookmarks) bookmarks")
    }
    
    private func processBookmarkSafely(_ bookmark: Bookmark, modelContext: ModelContext) async {
        await processBookmark(bookmark, modelContext: modelContext)
    }
    
    // MARK: - Private Methods
    
    private func generateTags(for content: WebContent, bookmark: Bookmark) async -> [AITag] {
        // Combine title, description, and content for analysis
        let fullText = [bookmark.title, content.title, content.description, content.textContent]
            .compactMap { $0 }
            .joined(separator: " ")
        
        // Preprocess text
        let processedText = preprocessText(fullText)
        
        // Generate tags using multiple approaches
        var allTags: [AITag] = []
        
        // 1. CoreML-based classification (if available)
        if isModelLoaded {
            allTags.append(contentsOf: await generateCoreMLTags(from: processedText))
        }
        
        // 2. Domain-based tagging
        allTags.append(contentsOf: generateDomainTags(from: bookmark.url))
        
        // 3. NLP-based categorization
        allTags.append(contentsOf: await generateNLPTags(from: processedText))
        
        // 4. Keyword extraction
        allTags.append(contentsOf: generateKeywordTags(from: processedText))
        
        // 5. Content analysis
        allTags.append(contentsOf: generateContentTags(from: content))
        
        // Filter and rank tags
        return filterAndRankTags(allTags)
    }
    
    private func preprocessText(_ text: String) -> String {
        let lowercased = text.lowercased()
        let cleaned = lowercased.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
        let normalized = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateCoreMLTags(from text: String) async -> [AITag] {
        // Preprocess text for optimal DistilBERT input
        let processedText = preprocessTextForModel(text)
        
        // Get classifications from real DistilBERT model
        let classifications = await coreMLLoader.classifyText(processedText)
        
        print("🧠 DistilBERT generated \(classifications.count) classifications")
        
        // Convert to AI tags with source tracking
        let aiTags = classifications.compactMap { result -> AITag? in
            // Apply confidence filtering
            guard result.confidence > 0.15 else { return nil }
            
            return AITag(
                name: result.category,
                confidence: result.confidence,
                source: .coreml
            )
        }
        
        // Log successful classifications
        if !aiTags.isEmpty {
            let tagNames = aiTags.map { $0.name }.joined(separator: ", ")
            print("✅ DistilBERT tags: \(tagNames)")
        }
        
        return aiTags
    }
    
    private func preprocessTextForModel(_ text: String) -> String {
        // Enhanced preprocessing specifically for DistilBERT
        var processed = text
        
        // Remove excessive whitespace and normalize
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common HTML artifacts that might remain
        processed = processed.replacingOccurrences(of: "&nbsp;", with: " ")
        processed = processed.replacingOccurrences(of: "&amp;", with: "&")
        processed = processed.replacingOccurrences(of: "&lt;", with: "<")
        processed = processed.replacingOccurrences(of: "&gt;", with: ">")
        
        // Focus on the most relevant parts for classification
        // Prioritize title and beginning of content
        let words = processed.components(separatedBy: .whitespaces)
        let maxWords = 200 // Optimal for DistilBERT processing
        
        if words.count > maxWords {
            // Take first portion which usually contains the most relevant content
            let selectedWords = Array(words.prefix(maxWords))
            processed = selectedWords.joined(separator: " ")
        }
        
        return processed
    }
    
    private func generateDomainTags(from url: URL) -> [AITag] {
        guard let host = url.host() else { return [] }
        
        var tags: [AITag] = []
        
        // Extract domain-specific tags
        let domainMappings: [String: (category: String, confidence: Double)] = [
            "github.com": ("Development", 0.95),
            "stackoverflow.com": ("Programming", 0.9),
            "youtube.com": ("Entertainment", 0.8),
            "linkedin.com": ("Business", 0.85),
            "twitter.com": ("Social", 0.8),
            "instagram.com": ("Social", 0.8),
            "facebook.com": ("Social", 0.8),
            "amazon.com": ("Shopping", 0.9),
            "netflix.com": ("Entertainment", 0.9),
            "medium.com": ("Reading", 0.8),
            "reddit.com": ("Social", 0.75),
            "news.ycombinator.com": ("Technology", 0.85),
            "techcrunch.com": ("Technology", 0.9),
            "bloomberg.com": ("Business", 0.85),
            "cnn.com": ("News", 0.9),
            "bbc.com": ("News", 0.9)
        ]
        
        if let mapping = domainMappings[host] {
            tags.append(AITag(name: mapping.category, confidence: mapping.confidence, source: .domain))
        }
        
        // Generic domain analysis
        if host.contains("blog") {
            tags.append(AITag(name: "Blog", confidence: 0.7, source: .domain))
        }
        if host.contains("shop") || host.contains("store") {
            tags.append(AITag(name: "Shopping", confidence: 0.7, source: .domain))
        }
        if host.contains("news") {
            tags.append(AITag(name: "News", confidence: 0.7, source: .domain))
        }
        
        return tags
    }
    
    private func generateNLPTags(from text: String) async -> [AITag] {
        var tags: [AITag] = []
        
        // Use NaturalLanguage framework for categorization
        let classifier = NLLanguageRecognizer()
        classifier.processString(text)
        
        // Sentiment analysis
        if let dominantLanguage = classifier.dominantLanguage {
            let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
            sentimentAnalyzer.string = text
            let sentiment = sentimentAnalyzer.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            
            if let sentimentScore = sentiment.0?.rawValue, let score = Double(sentimentScore) {
                if score > 0.1 {
                    tags.append(AITag(name: "Positive", confidence: min(score, 1.0), source: .nlp))
                } else if score < -0.1 {
                    tags.append(AITag(name: "Critical", confidence: min(abs(score), 1.0), source: .nlp))
                }
            }
        }
        
        // Category classification based on keywords
        for (category, keywords) in categoryMappings {
            let matches = keywords.filter { keyword in
                text.localizedCaseInsensitiveContains(keyword)
            }
            
            if !matches.isEmpty {
                let confidence = min(Double(matches.count) / Double(keywords.count) * 2.0, 1.0)
                if confidence > 0.3 {
                    tags.append(AITag(name: category, confidence: confidence, source: .nlp))
                }
            }
        }
        
        return tags
    }
    
    private func generateKeywordTags(from text: String) -> [AITag] {
        var tags: [AITag] = []
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        var keywordCounts: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if let tag = tag, tag == .noun || tag == .adjective {
                let word = String(text[tokenRange]).lowercased()
                if word.count > 3 && !isStopWord(word) {
                    keywordCounts[word, default: 0] += 1
                }
            }
            return true
        }
        
        // Convert top keywords to tags
        let sortedKeywords = keywordCounts.sorted { $0.value > $1.value }.prefix(5)
        for (keyword, count) in sortedKeywords {
            let confidence = min(Double(count) / 10.0, 1.0)
            if confidence > 0.2 {
                tags.append(AITag(name: keyword.capitalized, confidence: confidence, source: .keywords))
            }
        }
        
        return tags
    }
    
    private func generateContentTags(from content: WebContent) -> [AITag] {
        var tags: [AITag] = []
        
        // Analyze content structure
        if content.hasVideo {
            tags.append(AITag(name: "Video", confidence: 0.8, source: .content))
        }
        if content.hasImages {
            tags.append(AITag(name: "Visual", confidence: 0.6, source: .content))
        }
        if content.hasCode {
            tags.append(AITag(name: "Programming", confidence: 0.9, source: .content))
        }
        if content.isArticle {
            tags.append(AITag(name: "Article", confidence: 0.7, source: .content))
        }
        if content.isTutorial {
            tags.append(AITag(name: "Tutorial", confidence: 0.8, source: .content))
        }
        
        return tags
    }
    
    private func filterAndRankTags(_ tags: [AITag]) -> [AITag] {
        // Group tags by name and combine confidence scores
        var tagGroups: [String: [AITag]] = [:]
        for tag in tags {
            tagGroups[tag.name, default: []].append(tag)
        }
        
        var finalTags: [AITag] = []
        for (name, groupTags) in tagGroups {
            // Calculate weighted confidence with source-based weighting
            let weightedConfidence = calculateWeightedConfidence(for: groupTags)
            
            // Apply minimum confidence threshold
            if weightedConfidence > 0.25 {
                // Determine primary source for the tag
                let primarySource = determinePrimarySource(from: groupTags)
                finalTags.append(AITag(name: name, confidence: weightedConfidence, source: primarySource))
            }
        }
        
        // Sort by confidence and return top tags
        let sortedTags = finalTags.sorted { tag1, tag2 in
            // Prioritize DistilBERT predictions
            if tag1.source == .coreml && tag2.source != .coreml {
                return true
            } else if tag1.source != .coreml && tag2.source == .coreml {
                return false
            }
            // Then sort by confidence
            return tag1.confidence > tag2.confidence
        }
        
        return Array(sortedTags.prefix(8))
    }
    
    private func calculateWeightedConfidence(for tags: [AITag]) -> Double {
        // Weight different sources differently
        let sourceWeights: [TagSource: Double] = [
            .coreml: 1.5,     // Highest weight for DistilBERT
            .domain: 1.2,     // Domain-based tags are reliable
            .nlp: 1.0,        // Standard weight for NLP
            .keywords: 0.8,   // Lower weight for simple keywords
            .content: 0.9     // Medium weight for content analysis
        ]
        
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for tag in tags {
            let weight = sourceWeights[tag.source] ?? 1.0
            weightedSum += tag.confidence * weight
            totalWeight += weight
        }
        
        let averageConfidence = totalWeight > 0 ? weightedSum / totalWeight : 0
        
        // Boost confidence for multiple source agreement
        let multiSourceBoost = tags.count > 1 ? 1.1 : 1.0
        
        return min(averageConfidence * multiSourceBoost, 1.0)
    }
    
    private func determinePrimarySource(from tags: [AITag]) -> TagSource {
        // Prioritize source by reliability
        let sourcePriority: [TagSource] = [.coreml, .domain, .nlp, .content, .keywords]
        
        for source in sourcePriority {
            if tags.contains(where: { $0.source == source }) {
                return source
            }
        }
        
        return tags.first?.source ?? .nlp
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "its", "may", "new", "now", "old", "see", "two", "who", "boy", "did", "man", "men", "say", "she", "use", "way", "will", "with"])
        return stopWords.contains(word.lowercased())
    }
    
    private func generateCacheKey(for bookmark: Bookmark) -> String {
        return "\(bookmark.url.absoluteString)_\(bookmark.title)".data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
    
    private func updateBookmarkWithTags(_ bookmark: Bookmark, tags: [AITag], modelContext: ModelContext) async {
        await MainActor.run {
            // Store AI-generated tags separately
            let highConfidenceTags = tags.filter { $0.confidence > 0.4 }
            bookmark.aiTags = highConfidenceTags.map { $0.name }
            
            // Merge AI tags with existing manual tags
            let allTags = Array(Set(bookmark.tags + bookmark.aiTags))
            bookmark.tags = allTags
            
            // Update AI processing metadata
            bookmark.isProcessed = true
            bookmark.aiProcessedDate = Date()
            bookmark.aiConfidence = highConfidenceTags.isEmpty ? 0.0 : 
                highConfidenceTags.reduce(0) { $0 + $1.confidence } / Double(highConfidenceTags.count)
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save bookmark with AI tags: \(error)")
            }
        }
    }
}

// MARK: - Supporting Models

struct AITag {
    let name: String
    let confidence: Double
    let source: TagSource
}

enum TagSource {
    case domain, nlp, keywords, content, coreml
}

struct WebContent {
    let title: String?
    let description: String?
    let textContent: String
    let hasVideo: Bool
    let hasImages: Bool
    let hasCode: Bool
    let isArticle: Bool
    let isTutorial: Bool
}

// MARK: - Caching System

private class AITaggingCache {
    private let cache = NSCache<NSString, NSArray>()
    private let cacheQueue = DispatchQueue(label: "ai.cache.queue", attributes: .concurrent)
    
    init() {
        cache.countLimit = 1000
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func getCachedTags(for key: String) -> [AITag]? {
        return cacheQueue.sync {
            guard let cachedArray = cache.object(forKey: key as NSString) as? [NSDictionary] else {
                return nil
            }
            
            return cachedArray.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let confidence = dict["confidence"] as? Double,
                      let sourceRaw = dict["source"] as? String else {
                    return nil
                }
                
                let source: TagSource
                switch sourceRaw {
                case "domain": source = .domain
                case "nlp": source = .nlp
                case "keywords": source = .keywords
                case "content": source = .content
                case "coreml": source = .coreml
                default: source = .nlp
                }
                
                return AITag(name: name, confidence: confidence, source: source)
            }
        }
    }
    
    func cacheTags(_ tags: [AITag], for key: String) {
        cacheQueue.async(flags: .barrier) {
            let dictArray = tags.map { tag in
                [
                    "name": tag.name,
                    "confidence": tag.confidence,
                    "source": String(describing: tag.source)
                ] as NSDictionary
            }
            
            self.cache.setObject(dictArray as NSArray, forKey: key as NSString)
        }
    }
}