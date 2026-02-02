import SwiftUI

enum TagChipSize {
    case small, medium, large
    
    var padding: EdgeInsets {
        switch self {
        case .small:
            return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        case .medium:
            return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        case .large:
            return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        }
    }
}

struct TagChip: View {
    let text: String
    let color: Color
    let size: TagChipSize
    let onTap: (() -> Void)?
    
    init(
        text: String,
        color: Color = CortexColors.accents.electricBlue,
        size: TagChipSize = .medium,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.color = color
        self.size = size
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    onTap()
                    HapticManager.shared.impact(.light)
                }) {
                    chipContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                chipContent
            }
        }
    }
    
    private var chipContent: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
            .foregroundColor(CortexColors.text.primary)
            .padding(size.padding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    }
            }
    }
}