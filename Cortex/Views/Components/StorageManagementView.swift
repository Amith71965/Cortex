import SwiftUI
import SwiftData

struct StorageManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    
    @State private var storageInfo: StorageInfo?
    @State private var isOptimizing = false
    @State private var optimizationResult: StorageOptimizationResult?
    @State private var showOptimizationAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if let info = storageInfo {
                storageStatsSection(info)
                optimizationSection
            } else {
                loadingSection
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            calculateStorage()
        }
        .alert("Storage Optimization", isPresented: $showOptimizationAlert) {
            Button("OK") { }
        } message: {
            Text(optimizationResult?.message ?? "")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.system(size: 40))
                .foregroundColor(CortexColors.accents.electricBlue)
            
            Text("Storage Management")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Optimize your app's storage usage")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(CortexColors.accents.electricBlue)
            
            Text("Calculating storage usage...")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func storageStatsSection(_ info: StorageInfo) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Storage Statistics")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StorageStatCard(
                        title: "Total Size",
                        value: info.formattedSize,
                        icon: "doc.fill",
                        color: info.totalSize > 50_000_000 ? .red : .green
                    )
                    
                    StorageStatCard(
                        title: "Images",
                        value: "\(info.imageCount)",
                        icon: "photo.fill",
                        color: .blue
                    )
                    
                    StorageStatCard(
                        title: "Bookmarks",
                        value: "\(info.bookmarkCount)",
                        icon: "bookmark.fill",
                        color: .purple
                    )
                    
                    StorageStatCard(
                        title: "Large Images",
                        value: "\(info.largeImageCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: info.largeImageCount > 0 ? .orange : .green
                    )
                }
            }
            .padding()
        }
    }
    
    private var optimizationSection: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Storage Optimization")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Compress and clean up images to save space")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    
                    if isOptimizing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(CortexColors.accents.electricBlue)
                            Text("Optimizing...")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        Button(action: optimizeStorage) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Optimize Storage")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        CortexColors.accents.electricBlue,
                                        CortexColors.accents.vibrantPurple
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            
            // Storage tips
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(CortexColors.accents.neonGreen)
                        Text("Storage Tips")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow("Images are compressed to 400px max", icon: "photo")
                        tipRow("Cache is limited to 25MB in memory", icon: "memorychip")
                        tipRow("Old images are removed when limit reached", icon: "trash")
                        tipRow("Optimization runs automatically when needed", icon: "gearshape")
                    }
                }
                .padding()
            }
        }
    }
    
    private func tipRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(CortexColors.accents.electricBlue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    private func calculateStorage() {
        storageInfo = StorageOptimizer.shared.calculateStorageUsage(bookmarks: bookmarks)
    }
    
    private func optimizeStorage() {
        isOptimizing = true
        
        Task {
            let result = await StorageOptimizer.shared.optimizeStorage(modelContext: modelContext)
            
            await MainActor.run {
                isOptimizing = false
                optimizationResult = result
                showOptimizationAlert = true
                
                // Recalculate storage after optimization
                calculateStorage()
            }
        }
    }
}

struct StorageStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(CortexColors.glass.overlay10)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CortexColors.glass.overlay15, lineWidth: 1)
        )
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, Tag.self, configurations: config)
        
        return StorageManagementView()
            .modelContainer(container)
            .background(
                LinearGradient(
                    colors: [
                        CortexColors.primary.deepSpace,
                        CortexColors.primary.darkBlue
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    } catch {
        return Text("Preview Error")
    }
}