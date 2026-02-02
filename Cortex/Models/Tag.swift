import Foundation
import SwiftData

@Model
class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String
    var isSystemGenerated: Bool
    var createdDate: Date
    var usageCount: Int
    
    init(
        name: String,
        color: String = "electricBlue",
        isSystemGenerated: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isSystemGenerated = isSystemGenerated
        self.createdDate = Date()
        self.usageCount = 0
    }
    
    func incrementUsage() {
        usageCount += 1
    }
    
    var displayColor: String {
        switch color {
        case "electricBlue":
            return "#00D4FF"
        case "vibrantPurple":
            return "#8B5CF6"
        case "hotPink":
            return "#F472B6"
        case "neonGreen":
            return "#10B981"
        case "orange":
            return "#F59E0B"
        default:
            return "#00D4FF"
        }
    }
}

extension Tag {
    static let predefinedTags = [
        Tag(name: "Work", color: "electricBlue", isSystemGenerated: true),
        Tag(name: "Personal", color: "hotPink", isSystemGenerated: true),
        Tag(name: "Learning", color: "neonGreen", isSystemGenerated: true),
        Tag(name: "Entertainment", color: "vibrantPurple", isSystemGenerated: true),
        Tag(name: "Shopping", color: "orange", isSystemGenerated: true),
        Tag(name: "News", color: "electricBlue", isSystemGenerated: true),
        Tag(name: "Social", color: "hotPink", isSystemGenerated: true),
        Tag(name: "Reference", color: "neonGreen", isSystemGenerated: true)
    ]
}