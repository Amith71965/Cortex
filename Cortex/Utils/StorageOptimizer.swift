import Foundation
import UIKit
import SwiftData

/// Storage optimization utilities for managing app data efficiently
class StorageOptimizer {
    static let shared = StorageOptimizer()
    
    // Storage limits
    private let maxPreviewImageSize: Int = 512 * 1024 // 512KB per image
    private let maxTotalStorageSize: Int = 100 * 1024 * 1024 // 100MB total
    private let imageCompressionQuality: CGFloat = 0.7
    private let maxImageDimension: CGFloat = 400 // Max width/height
    
    private init() {}
    
    // MARK: - Image Optimization
    
    /// Optimize image data for storage
    func optimizeImageForStorage(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        // Resize if too large
        let optimizedImage = resizeImage(image, maxDimension: maxImageDimension)
        
        // Compress with quality setting
        guard let compressedData = optimizedImage.jpegData(compressionQuality: imageCompressionQuality) else {
            return nil
        }
        
        // Check size limit
        if compressedData.count > maxPreviewImageSize {
            // Try lower compression
            return optimizedImage.jpegData(compressionQuality: 0.5)
        }
        
        return compressedData
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio >= 1.0 {
            return image // No need to resize
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - Storage Management
    
    /// Check total storage usage
    func calculateStorageUsage(bookmarks: [Bookmark]) -> StorageInfo {
        var totalSize = 0
        var imageCount = 0
        var largeImages = 0
        
        for bookmark in bookmarks {
            if let imageData = bookmark.previewImage {
                totalSize += imageData.count
                imageCount += 1
                
                if imageData.count > maxPreviewImageSize {
                    largeImages += 1
                }
            }
        }
        
        return StorageInfo(
            totalSize: totalSize,
            imageCount: imageCount,
            largeImageCount: largeImages,
            bookmarkCount: bookmarks.count
        )
    }
    
    /// Clean up storage by removing old/large images
    func optimizeStorage(modelContext: ModelContext) async -> StorageOptimizationResult {
        let request = FetchDescriptor<Bookmark>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        
        guard let bookmarks = try? modelContext.fetch(request) else {
            return StorageOptimizationResult(success: false, message: "Failed to fetch bookmarks")
        }
        
        let initialInfo = calculateStorageUsage(bookmarks: bookmarks)
        var optimizedCount = 0
        var removedCount = 0
        
        // Check if we need to optimize
        guard initialInfo.totalSize > maxTotalStorageSize else {
            return StorageOptimizationResult(
                success: true, 
                message: "Storage within limits (\(formatBytes(initialInfo.totalSize)))"
            )
        }
        
        for bookmark in bookmarks {
            guard let originalData = bookmark.previewImage else { continue }
            
            if originalData.count > maxPreviewImageSize {
                // Try to optimize large images
                if let optimizedData = optimizeImageForStorage(originalData) {
                    bookmark.previewImage = optimizedData
                    optimizedCount += 1
                } else {
                    // Remove if can't optimize
                    bookmark.previewImage = nil
                    removedCount += 1
                }
            }
        }
        
        // Remove oldest images if still over limit
        let sortedByDate = bookmarks.sorted { $0.dateAdded < $1.dateAdded }
        for bookmark in sortedByDate {
            let currentSize = calculateStorageUsage(bookmarks: bookmarks).totalSize
            if currentSize <= maxTotalStorageSize { break }
            
            if bookmark.previewImage != nil {
                bookmark.previewImage = nil
                removedCount += 1
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            let finalInfo = calculateStorageUsage(bookmarks: bookmarks)
            
            return StorageOptimizationResult(
                success: true,
                message: """
                Storage optimized successfully:
                • Before: \(formatBytes(initialInfo.totalSize))
                • After: \(formatBytes(finalInfo.totalSize))
                • Optimized: \(optimizedCount) images
                • Removed: \(removedCount) images
                """,
                beforeSize: initialInfo.totalSize,
                afterSize: finalInfo.totalSize
            )
        } catch {
            return StorageOptimizationResult(
                success: false,
                message: "Failed to save optimizations: \(error)"
            )
        }
    }
    
    // MARK: - Utility
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Supporting Types

struct StorageInfo {
    let totalSize: Int
    let imageCount: Int
    let largeImageCount: Int
    let bookmarkCount: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
}

struct StorageOptimizationResult {
    let success: Bool
    let message: String
    let beforeSize: Int?
    let afterSize: Int?
    
    init(success: Bool, message: String, beforeSize: Int? = nil, afterSize: Int? = nil) {
        self.success = success
        self.message = message
        self.beforeSize = beforeSize
        self.afterSize = afterSize
    }
}

// MARK: - Enhanced AI Cache

extension AITaggingService {
    
    /// Optimized cache with better memory management
    private class EnhancedAICache {
        private let cache = NSCache<NSString, CacheEntry>()
        private let cacheQueue = DispatchQueue(label: "ai.cache.queue", attributes: .concurrent)
        private let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
        
        init() {
            cache.countLimit = 500  // Reduced from 1000
            cache.totalCostLimit = 25 * 1024 * 1024 // Reduced to 25MB
            
            // Auto-cleanup timer
            Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                self.cleanupExpiredEntries()
            }
        }
        
        func getCachedTags(for key: String) -> [AITag]? {
            return cacheQueue.sync {
                guard let entry = cache.object(forKey: key as NSString) else {
                    return nil
                }
                
                // Check if expired
                if Date().timeIntervalSince(entry.timestamp) > maxAge {
                    cache.removeObject(forKey: key as NSString)
                    return nil
                }
                
                return entry.tags
            }
        }
        
        func cacheTags(_ tags: [AITag], for key: String) {
            cacheQueue.async(flags: .barrier) {
                let entry = CacheEntry(tags: tags, timestamp: Date())
                let cost = tags.count * 100 // Approximate memory cost
                self.cache.setObject(entry, forKey: key as NSString, cost: cost)
            }
        }
        
        private func cleanupExpiredEntries() {
            // NSCache handles most cleanup automatically
            // This is just for explicit age-based cleanup
        }
    }
    
    private class CacheEntry {
        let tags: [AITag]
        let timestamp: Date
        
        init(tags: [AITag], timestamp: Date) {
            self.tags = tags
            self.timestamp = timestamp
        }
    }
}