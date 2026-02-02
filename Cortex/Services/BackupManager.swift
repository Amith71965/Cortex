import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Comprehensive backup and export manager for Cortex data
@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastBackupDate: Date?
    @Published var autoBackupEnabled = true
    @Published var backupReminderInterval: BackupReminderInterval = .weekly
    
    private let userDefaults = UserDefaults.standard
    private let backupDateKey = "lastBackupDate"
    private let autoBackupKey = "autoBackupEnabled"
    private let reminderIntervalKey = "backupReminderInterval"
    
    private init() {
        loadSettings()
        scheduleBackupReminders()
    }
    
    // MARK: - Export Functionality
    
    /// Export all bookmarks to JSON file
    func exportBookmarks(_ bookmarks: [Bookmark]) async -> Result<URL, BackupError> {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let exportData = BookmarkExportData(
                exportDate: Date(),
                version: "1.0",
                bookmarks: bookmarks.map { BookmarkExportItem(from: $0) }
            )
            
            let jsonData = try JSONEncoder().encode(exportData)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                       in: .userDomainMask)[0]
            let fileName = "cortex_bookmarks_\(dateFormatter.string(from: Date())).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            updateLastBackupDate()
            return .success(fileURL)
            
        } catch {
            return .failure(.exportFailed(error.localizedDescription))
        }
    }
    
    /// Export bookmarks with images to ZIP file
    func exportBookmarksWithImages(_ bookmarks: [Bookmark]) async -> Result<URL, BackupError> {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                       in: .userDomainMask)[0]
            let tempDir = documentsPath.appendingPathComponent("temp_export")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Export JSON data
            let exportData = BookmarkExportData(
                exportDate: Date(),
                version: "1.0",
                bookmarks: bookmarks.map { BookmarkExportItem(from: $0) }
            )
            
            let jsonData = try JSONEncoder().encode(exportData)
            let jsonURL = tempDir.appendingPathComponent("bookmarks.json")
            try jsonData.write(to: jsonURL)
            
            // Export images
            let imagesDir = tempDir.appendingPathComponent("images")
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            
            for bookmark in bookmarks {
                if let imageData = bookmark.previewImage {
                    let imageURL = imagesDir.appendingPathComponent("\(bookmark.id).jpg")
                    try imageData.write(to: imageURL)
                }
            }
            
            // Create ZIP file
            let zipFileName = "cortex_backup_\(dateFormatter.string(from: Date())).zip"
            let zipURL = documentsPath.appendingPathComponent(zipFileName)
            
            try await createZipFile(from: tempDir, to: zipURL)
            
            // Cleanup temp directory
            try FileManager.default.removeItem(at: tempDir)
            
            updateLastBackupDate()
            return .success(zipURL)
            
        } catch {
            return .failure(.exportFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Import Functionality
    
    /// Import bookmarks from JSON file
    func importBookmarks(from url: URL, modelContext: ModelContext) async -> Result<ImportResult, BackupError> {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(BookmarkExportData.self, from: data)
            
            var importedCount = 0
            var skippedCount = 0
            
            for item in exportData.bookmarks {
                // Check if bookmark already exists
                let request = FetchDescriptor<Bookmark>(
                    predicate: #Predicate { $0.url.absoluteString == item.url }
                )
                
                if let existingBookmarks = try? modelContext.fetch(request),
                   !existingBookmarks.isEmpty {
                    skippedCount += 1
                    continue
                }
                
                // Create new bookmark
                let bookmark = Bookmark(
                    title: item.title,
                    url: URL(string: item.url) ?? URL(string: "https://example.com")!,
                    tags: item.tags,
                    isProcessed: item.isProcessed,
                    isFavorite: item.isFavorite,
                    notes: item.notes
                )
                
                bookmark.id = item.id
                bookmark.dateAdded = item.dateAdded
                bookmark.aiTags = item.aiTags
                bookmark.aiConfidence = item.aiConfidence
                bookmark.lastOpened = item.lastOpened
                bookmark.openCount = item.openCount
                
                if let aiProcessedDate = item.aiProcessedDate {
                    bookmark.aiProcessedDate = aiProcessedDate
                }
                
                modelContext.insert(bookmark)
                importedCount += 1
            }
            
            try modelContext.save()
            
            return .success(ImportResult(
                imported: importedCount,
                skipped: skippedCount,
                total: exportData.bookmarks.count
            ))
            
        } catch {
            return .failure(.importFailed(error.localizedDescription))
        }
    }
    
    // MARK: - iCloud Document Sync
    
    /// Save backup to iCloud Drive
    func saveToiCloudDrive(_ fileURL: URL) async -> Result<URL, BackupError> {
        do {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                return .failure(.iCloudNotAvailable)
            }
            
            let cortexFolder = iCloudURL.appendingPathComponent("Documents/Cortex Backups")
            try FileManager.default.createDirectory(at: cortexFolder, withIntermediateDirectories: true)
            
            let fileName = fileURL.lastPathComponent
            let iCloudFileURL = cortexFolder.appendingPathComponent(fileName)
            
            // Copy file to iCloud
            if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                try FileManager.default.removeItem(at: iCloudFileURL)
            }
            
            try FileManager.default.copyItem(at: fileURL, to: iCloudFileURL)
            
            // Start download if needed
            try FileManager.default.startDownloadingUbiquitousItem(at: iCloudFileURL)
            
            return .success(iCloudFileURL)
            
        } catch {
            return .failure(.iCloudSyncFailed(error.localizedDescription))
        }
    }
    
    /// List available iCloud backups
    func listICloudBackups() async -> Result<[BackupFile], BackupError> {
        do {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                return .failure(.iCloudNotAvailable)
            }
            
            let cortexFolder = iCloudURL.appendingPathComponent("Documents/Cortex Backups")
            
            guard FileManager.default.fileExists(atPath: cortexFolder.path) else {
                return .success([])
            }
            
            let files = try FileManager.default.contentsOfDirectory(at: cortexFolder, 
                                                                  includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            
            let backupFiles = try files.compactMap { url -> BackupFile? in
                let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                
                return BackupFile(
                    url: url,
                    name: url.lastPathComponent,
                    date: resourceValues.contentModificationDate ?? Date(),
                    size: resourceValues.fileSize ?? 0,
                    isDownloaded: try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus == .current
                )
            }.sorted { $0.date > $1.date }
            
            return .success(backupFiles)
            
        } catch {
            return .failure(.iCloudSyncFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Automatic Backup
    
    /// Perform automatic backup if needed
    func performAutomaticBackupIfNeeded(_ bookmarks: [Bookmark]) async {
        guard autoBackupEnabled else { return }
        
        let shouldBackup = shouldPerformAutomaticBackup()
        guard shouldBackup else { return }
        
        print("🔄 Performing automatic backup...")
        
        let result = await exportBookmarks(bookmarks)
        switch result {
        case .success(let fileURL):
            // Save to iCloud Drive
            let iCloudResult = await saveToiCloudDrive(fileURL)
            switch iCloudResult {
            case .success:
                print("✅ Automatic backup completed successfully")
                // Clean up local file after iCloud upload
                try? FileManager.default.removeItem(at: fileURL)
            case .failure(let error):
                print("⚠️ iCloud backup failed: \(error)")
            }
        case .failure(let error):
            print("❌ Automatic backup failed: \(error)")
        }
    }
    
    private func shouldPerformAutomaticBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        
        let interval: TimeInterval
        switch backupReminderInterval {
        case .daily:
            interval = 24 * 60 * 60
        case .weekly:
            interval = 7 * 24 * 60 * 60
        case .monthly:
            interval = 30 * 24 * 60 * 60
        }
        
        return Date().timeIntervalSince(lastBackup) > interval
    }
    
    // MARK: - Backup Reminders
    
    func scheduleBackupReminders() {
        Task {
            await BackupNotificationManager.shared.scheduleBackupReminder(interval: backupReminderInterval)
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        lastBackupDate = userDefaults.object(forKey: backupDateKey) as? Date
        autoBackupEnabled = userDefaults.bool(forKey: autoBackupKey)
        
        if let intervalRaw = userDefaults.object(forKey: reminderIntervalKey) as? String,
           let interval = BackupReminderInterval(rawValue: intervalRaw) {
            backupReminderInterval = interval
        }
    }
    
    private func updateLastBackupDate() {
        lastBackupDate = Date()
        userDefaults.set(lastBackupDate, forKey: backupDateKey)
    }
    
    func updateSettings(autoBackup: Bool, reminderInterval: BackupReminderInterval) {
        autoBackupEnabled = autoBackup
        backupReminderInterval = reminderInterval
        
        userDefaults.set(autoBackup, forKey: autoBackupKey)
        userDefaults.set(reminderInterval.rawValue, forKey: reminderIntervalKey)
        
        scheduleBackupReminders()
    }
    
    // MARK: - Utility
    
    private func createZipFile(from sourceURL: URL, to destinationURL: URL) async throws {
        // This would use a ZIP library like ZIPFoundation
        // For now, this is a placeholder
        throw BackupError.exportFailed("ZIP creation not implemented")
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

// MARK: - Supporting Types

struct BookmarkExportData: Codable {
    let exportDate: Date
    let version: String
    let bookmarks: [BookmarkExportItem]
}

struct BookmarkExportItem: Codable {
    let id: UUID
    let title: String
    let url: String
    let dateAdded: Date
    let tags: [String]
    let isProcessed: Bool
    let isFavorite: Bool
    let notes: String?
    let lastOpened: Date?
    let openCount: Int
    let aiTags: [String]
    let aiProcessedDate: Date?
    let aiConfidence: Double
    
    init(from bookmark: Bookmark) {
        self.id = bookmark.id
        self.title = bookmark.title
        self.url = bookmark.url.absoluteString
        self.dateAdded = bookmark.dateAdded
        self.tags = bookmark.tags
        self.isProcessed = bookmark.isProcessed
        self.isFavorite = bookmark.isFavorite
        self.notes = bookmark.notes
        self.lastOpened = bookmark.lastOpened
        self.openCount = bookmark.openCount
        self.aiTags = bookmark.aiTags
        self.aiProcessedDate = bookmark.aiProcessedDate
        self.aiConfidence = bookmark.aiConfidence
    }
}

struct ImportResult {
    let imported: Int
    let skipped: Int
    let total: Int
}

struct BackupFile {
    let url: URL
    let name: String
    let date: Date
    let size: Int
    let isDownloaded: Bool
}

enum BackupReminderInterval: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum BackupError: Error, LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case iCloudNotAvailable
    case iCloudSyncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        case .iCloudNotAvailable:
            return "iCloud Drive is not available"
        case .iCloudSyncFailed(let message):
            return "iCloud sync failed: \(message)"
        }
    }
}