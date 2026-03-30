import SwiftUI

struct GlassSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? CortexColors.accents.electricBlue : CortexColors.text.tertiary)

            TextField(placeholder, text: $searchText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .focused($isFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                    HapticManager.shared.impact(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CortexColors.text.tertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(CortexColors.glass.overlay10)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused
                                ? CortexColors.accents.electricBlue.opacity(0.5)
                                : CortexColors.glass.borderSubtle,
                            lineWidth: 1
                        )
                }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
