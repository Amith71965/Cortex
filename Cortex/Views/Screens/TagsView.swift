import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @State private var searchText = ""
    @State private var showingCreateTag = false
    @State private var selectedTag: String? = nil
    
    private var allTags: [String] {
        let tagSet = Set(bookmarks.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }
    
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func bookmarksForTag(_ tag: String) -> [Bookmark] {
        bookmarks.filter { $0.tags.contains(tag) }
    }
    
    private var tagColors: [String: Color] {
        let colors = [
            CortexColors.accents.electricBlue,
            CortexColors.accents.vibrantPurple,
            CortexColors.accents.hotPink,
            CortexColors.accents.neonGreen,
            CortexColors.accents.orange
        ]
        
        var result: [String: Color] = [:]
        for (index, tag) in allTags.enumerated() {
            result[tag] = colors[index % colors.count]
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            searchSection
            
            if selectedTag == nil {
                tagsOverviewSection
            } else {
                tagDetailSection
            }
        }
        .sheet(isPresented: $showingCreateTag) {
            createTagSheet
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let selectedTag = selectedTag {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            self.selectedTag = nil
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back to Tags")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(CortexColors.accents.electricBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(selectedTag)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text("\(bookmarksForTag(selectedTag).count) bookmarks")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                } else {
                    Text("Tags")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text("\(allTags.count) tags")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                }
            }
            
            Spacer()
            
            if selectedTag == nil {
                Button(action: {
                    showingCreateTag = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CortexColors.text.secondary)
                        .padding(12)
                        .glassCard(cornerRadius: 12, shadowRadius: 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var searchSection: some View {
        VStack {
            GlassSearchBar(
                searchText: $searchText,
                placeholder: selectedTag == nil ? "Search tags..." : "Search bookmarks in \(selectedTag ?? "")..."
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var tagsOverviewSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredTags.isEmpty {
                    emptyTagsView
                } else {
                    ForEach(filteredTags, id: \.self) { tag in
                        TagRow(
                            tag: tag,
                            color: tagColors[tag] ?? CortexColors.accents.electricBlue,
                            bookmarkCount: bookmarksForTag(tag).count
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTag = tag
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var tagDetailSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let tagBookmarks = selectedTag != nil ? bookmarksForTag(selectedTag!) : []
                
                if tagBookmarks.isEmpty {
                    emptyBookmarksView
                } else {
                    ForEach(tagBookmarks, id: \.id) { bookmark in
                        BookmarkCard(
                            bookmark: bookmark,
                            onTap: {
                                bookmark.incrementOpenCount()
                                try? modelContext.save()
                                // TODO: Open URL
                            },
                            onFavoriteToggle: {
                                bookmark.isFavorite.toggle()
                                try? modelContext.save()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyTagsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CortexColors.text.tertiary)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No tags yet" : "No matching tags")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text(searchText.isEmpty ?
                     "Tags will appear here as you add bookmarks" :
                     "Try adjusting your search criteria"
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
        .glassCard(cornerRadius: 20, shadowRadius: 8)
        .padding(20)
    }
    
    private var emptyBookmarksView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CortexColors.text.tertiary)
            
            VStack(spacing: 8) {
                Text("No bookmarks found")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text("This tag doesn't have any bookmarks yet")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 60)
        .glassCard(cornerRadius: 20, shadowRadius: 8)
        .padding(20)
    }
    
    private var createTagSheet: some View {
        CreateTagView()
    }
}

struct TagRow: View {
    let tag: String
    let color: Color
    let bookmarkCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
            HapticManager.shared.impact(.light)
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tag)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text("\(bookmarkCount) bookmark\(bookmarkCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CortexColors.text.tertiary)
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

struct CreateTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tagName = ""
    @State private var selectedColor = CortexColors.accents.electricBlue
    
    private let availableColors = [
        CortexColors.accents.electricBlue,
        CortexColors.accents.vibrantPurple,
        CortexColors.accents.hotPink,
        CortexColors.accents.neonGreen,
        CortexColors.accents.orange
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Create Tag")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Tag Name")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                TextField("Enter tag name", text: $tagName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .padding(16)
                    .glassCard(cornerRadius: 12, shadowRadius: 8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Color")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                HStack(spacing: 12) {
                    ForEach(availableColors.indices, id: \.self) { index in
                        Button(action: {
                            selectedColor = availableColors[index]
                            HapticManager.shared.impact(.light)
                        }) {
                            Circle()
                                .fill(availableColors[index])
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if selectedColor == availableColors[index] {
                                        Circle()
                                            .stroke(CortexColors.text.primary, lineWidth: 3)
                                            .frame(width: 46, height: 46)
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                // TODO: Create tag
                dismiss()
            }) {
                Text("Create Tag")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .glassCard(cornerRadius: 16, shadowRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
        }
        .padding(20)
        .background {
            LinearGradient(
                colors: [
                    CortexColors.primary.deepSpace,
                    CortexColors.primary.darkBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}