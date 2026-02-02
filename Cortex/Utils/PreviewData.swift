import Foundation
import SwiftData

extension Bookmark {
    static var preview: Bookmark {
        Bookmark(
            title: "Apple Developer Documentation",
            url: URL(string: "https://developer.apple.com/documentation/")!,
            tags: ["Development", "iOS", "Reference"],
            notes: "Official Apple documentation for iOS development"
        )
    }
    
    static var previewBookmarks: [Bookmark] {
        [
            Bookmark(
                title: "SwiftUI Tutorials",
                url: URL(string: "https://developer.apple.com/tutorials/swiftui")!,
                tags: ["SwiftUI", "Tutorial", "iOS"],
                notes: "Learn SwiftUI with official tutorials"
            ),
            Bookmark(
                title: "GitHub - Apple/swift",
                url: URL(string: "https://github.com/apple/swift")!,
                tags: ["Swift", "Open Source", "Programming"],
                notes: "The Swift programming language repository"
            ),
            Bookmark(
                title: "Hacker News",
                url: URL(string: "https://news.ycombinator.com")!,
                tags: ["News", "Technology", "Programming"],
                notes: "Tech news and discussion"
            )
        ]
    }
}

@MainActor
func setupPreviewContainer() -> ModelContainer {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, Tag.self, configurations: config)
        
        // Add sample data
        let context = container.mainContext
        for bookmark in Bookmark.previewBookmarks {
            context.insert(bookmark)
        }
        
        try context.save()
        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}