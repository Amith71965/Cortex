import SwiftUI

struct BookmarkCard: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
            HapticManager.shared.impact(.light)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AsyncImage(url: bookmark.faviconURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "globe")
                            .foregroundColor(CortexColors.text.tertiary)
                    }
                    .frame(width: 16, height: 16)
                    
                    Text(bookmark.domain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                    
                    Spacer()
                    
                    Button(action: {
                        onFavoriteToggle()
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: bookmark.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(bookmark.isFavorite ? CortexColors.accents.hotPink : CortexColors.text.tertiary)
                    }
                }
                
                Text(bookmark.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !bookmark.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(bookmark.tags, id: \.self) { tag in
                                TagChip(text: tag, size: .small)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                HStack {
                    Text(bookmark.formattedDateAdded)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                    
                    Spacer()
                    
                    if bookmark.openCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 10, weight: .medium))
                            Text("\(bookmark.openCount)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(CortexColors.text.tertiary)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: isPressed ? 5 : 12)
            .scaleEffect(isPressed ? 0.98 : 1.0)
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