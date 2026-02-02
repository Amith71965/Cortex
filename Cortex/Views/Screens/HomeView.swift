import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.dateAdded, order: .reverse) private var bookmarks: [Bookmark]
    @StateObject private var aiService = AITaggingService.shared
    @State private var showingAddBookmark = false
    @State private var showingAIProgress = false
    @State private var showingQRScanner = false
    @State private var showingImportOptions = false
    
    init() {
        print("🏠 HomeView initializing...")
    }
    
    private var recentBookmarks: [Bookmark] {
        Array(bookmarks.prefix(5))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                UserProfileHeader()
                
                headerSection
                
                featureButtonsSection
                
                recentBookmarksSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkView()
        }
        .sheet(isPresented: $showingAIProgress) {
            AIProcessingView(aiService: aiService)
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView()
        }
        .sheet(isPresented: $showingImportOptions) {
            ImportOptionsView()
        }
        .overlay(alignment: .top) {
            if aiService.isProcessing {
                AIProcessingBanner(progress: aiService.processingProgress)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back!")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.secondary)
                    
                    Text("Cortex")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CortexColors.accents.electricBlue, CortexColors.accents.vibrantPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(bookmarks.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text("Bookmarks")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                }
                .glassCard(cornerRadius: 12, shadowRadius: 8)
                .padding(12)
            }
        }
    }
    
    private var featureButtonsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                FeatureButton(
                    title: "Quick Add",
                    icon: "plus.circle.fill",
                    accentColor: CortexColors.accents.electricBlue
                ) {
                    showingAddBookmark = true
                }
                
                FeatureButton(
                    title: "Scan QR",
                    icon: "qrcode.viewfinder",
                    accentColor: CortexColors.accents.vibrantPurple
                ) {
                    showingQRScanner = true
                }
                
                FeatureButton(
                    title: "Import",
                    icon: "square.and.arrow.down.fill",
                    accentColor: CortexColors.accents.neonGreen
                ) {
                    showingImportOptions = true
                }
                
                FeatureButton(
                    title: "AI Organize",
                    icon: "brain.head.profile",
                    accentColor: CortexColors.accents.hotPink
                ) {
                    startAIOrganizing()
                }
            }
        }
    }
    
    private var recentBookmarksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Bookmarks")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
                
                if !bookmarks.isEmpty {
                    Button("View All") {
                        // TODO: Navigate to Library tab
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.accents.electricBlue)
                }
            }
            
            if recentBookmarks.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentBookmarks, id: \.id) { bookmark in
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
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(CortexColors.text.tertiary)
            
            VStack(spacing: 8) {
                Text("No bookmarks yet")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text("Start by adding your first bookmark using the Quick Add button above")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingAddBookmark = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Bookmark")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(CortexColors.text.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 20, shadowRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 40)
        .glassCard(cornerRadius: 20, shadowRadius: 8)
        .padding(20)
    }
    
    private func startAIOrganizing() {
        let unprocessedBookmarks = bookmarks.filter { !$0.isProcessed }
        
        if unprocessedBookmarks.isEmpty {
            HapticManager.shared.notification(.warning)
            return
        }
        
        showingAIProgress = true
        
        Task {
            await aiService.processMultipleBookmarks(unprocessedBookmarks, modelContext: modelContext)
            HapticManager.shared.notification(.success)
        }
    }
}