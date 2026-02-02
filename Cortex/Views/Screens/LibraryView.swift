import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @State private var searchText = ""
    @State private var selectedFilter = BookmarkFilter.all
    @State private var showingSortOptions = false
    @State private var sortOption = SortOption.dateAdded
    
    enum BookmarkFilter: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case unprocessed = "Unprocessed"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .favorites: return "heart.fill"
            case .unprocessed: return "brain.head.profile"
            case .recent: return "clock.fill"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case domain = "Domain"
        case openCount = "Most Opened"
        
        var icon: String {
            switch self {
            case .dateAdded: return "calendar"
            case .title: return "textformat.abc"
            case .domain: return "globe"
            case .openCount: return "eye"
            }
        }
    }
    
    private var filteredBookmarks: [Bookmark] {
        let filtered: [Bookmark]
        
        switch selectedFilter {
        case .all:
            filtered = bookmarks
        case .favorites:
            filtered = bookmarks.filter { $0.isFavorite }
        case .unprocessed:
            filtered = bookmarks.filter { !$0.isProcessed }
        case .recent:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = bookmarks.filter { $0.dateAdded >= sevenDaysAgo }
        }
        
        let searchFiltered = searchText.isEmpty ? filtered : filtered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        return searchFiltered.sorted { bookmark1, bookmark2 in
            switch sortOption {
            case .dateAdded:
                return bookmark1.dateAdded > bookmark2.dateAdded
            case .title:
                return bookmark1.title.localizedCaseInsensitiveCompare(bookmark2.title) == .orderedAscending
            case .domain:
                return bookmark1.domain.localizedCaseInsensitiveCompare(bookmark2.domain) == .orderedAscending
            case .openCount:
                return bookmark1.openCount > bookmark2.openCount
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            searchAndFilterSection
            
            bookmarksList
        }
        .sheet(isPresented: $showingSortOptions) {
            sortOptionsSheet
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text("\(filteredBookmarks.count) bookmarks")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
            }
            
            Spacer()
            
            Button(action: {
                showingSortOptions = true
            }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CortexColors.text.secondary)
                    .padding(12)
                    .glassCard(cornerRadius: 12, shadowRadius: 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            GlassSearchBar(
                searchText: $searchText,
                placeholder: "Search bookmarks, tags, domains..."
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BookmarkFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                            HapticManager.shared.impact(.light)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredBookmarks, id: \.id) { bookmark in
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
                
                if filteredBookmarks.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CortexColors.text.tertiary)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No bookmarks found" : "No results found")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text(searchText.isEmpty ?
                     "Bookmarks matching \"\(selectedFilter.rawValue)\" will appear here" :
                     "Try adjusting your search or filter criteria"
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
    
    private var sortOptionsSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Sort Options")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
                
                Button("Done") {
                    showingSortOptions = false
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.accents.electricBlue)
            }
            
            VStack(spacing: 12) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortOption = option
                        showingSortOptions = false
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(sortOption == option ? CortexColors.accents.electricBlue : CortexColors.text.secondary)
                            
                            Text(option.rawValue)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(CortexColors.text.primary)
                            
                            Spacer()
                            
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(CortexColors.accents.electricBlue)
                            }
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 12, shadowRadius: 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
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

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? CortexColors.text.primary : CortexColors.text.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? CortexColors.accents.electricBlue.opacity(0.2) : CortexColors.glass.overlay10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? CortexColors.accents.electricBlue.opacity(0.5) : CortexColors.glass.borderSubtle,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}