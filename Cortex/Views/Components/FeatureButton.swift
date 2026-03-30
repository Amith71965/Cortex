import SwiftUI

struct FeatureButton: View {
    let title: String
    let icon: String
    let accentColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.impact(.medium)
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(accentColor)
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .glassCard(cornerRadius: 16, shadowRadius: isPressed ? 4 : 12)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}
