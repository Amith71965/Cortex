import SwiftUI

// MARK: - Color System

struct CortexColors {
    struct primary {
        static let deepSpace = Color(red: 0.039, green: 0.055, blue: 0.102)  // #0A0E1A
        static let darkBlue  = Color(red: 0.051, green: 0.078, blue: 0.129)  // #0D1421
        static let mediumBlue = Color(red: 0.067, green: 0.094, blue: 0.153) // #111827
    }

    struct accents {
        static let electricBlue  = Color(red: 0.0,   green: 0.831, blue: 1.0)   // #00D4FF
        static let vibrantPurple = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
        static let hotPink       = Color(red: 0.957, green: 0.447, blue: 0.714) // #F472B6
        static let neonGreen     = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
        static let orange        = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    }

    struct text {
        static let primary   = Color.white
        static let secondary = Color.white.opacity(0.70)
        static let tertiary  = Color.white.opacity(0.40)
    }

    struct glass {
        static let overlay05    = Color.white.opacity(0.05)
        static let overlay10    = Color.white.opacity(0.10)
        static let overlay15    = Color.white.opacity(0.15)
        static let overlay20    = Color.white.opacity(0.20)
        static let borderSubtle = Color.white.opacity(0.15)
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(CortexColors.glass.overlay10)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(CortexColors.glass.borderSubtle, lineWidth: 1)
                    }
            }
            .shadow(
                color: Color.black.opacity(0.25),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 3
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 12) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}

// MARK: - GlassCard View (container)

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(CortexColors.glass.overlay10)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(CortexColors.glass.borderSubtle, lineWidth: 1)
                    }
            }
            .shadow(
                color: Color.black.opacity(0.25),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 3
            )
    }
}
