import Foundation
import SwiftData

@Model
class Bookmark {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: URL
    var dateAdded: Date
    var tags: [String]
    var previewImage: Data?
    var isProcessed: Bool
    var isFavorite: Bool
    var notes: String?
    var lastOpened: Date?
    var openCount: Int
    var aiTags: [String]
    var aiProcessedDate: Date?
    var aiConfidence: Double
    
    init(
        title: String,
        url: URL,
        tags: [String] = [],
        previewImage: Data? = nil,
        isProcessed: Bool = false,
        isFavorite: Bool = false,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.dateAdded = Date()
        self.tags = tags
        self.previewImage = previewImage
        self.isProcessed = isProcessed
        self.isFavorite = isFavorite
        self.notes = notes
        self.lastOpened = nil
        self.openCount = 0
        self.aiTags = []
        self.aiProcessedDate = nil
        self.aiConfidence = 0.0
    }
    
    var domain: String {
        url.host() ?? "Unknown"
    }
    
    var faviconURL: URL? {
        guard let host = url.host() else { return nil }
        return URL(string: "https://\(host)/favicon.ico")
    }
    
    func incrementOpenCount() {
        openCount += 1
        lastOpened = Date()
    }
    
    var formattedDateAdded: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dateAdded, relativeTo: Date())
    }
}