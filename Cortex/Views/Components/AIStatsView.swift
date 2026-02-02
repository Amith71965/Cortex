import SwiftUI
import SwiftData

struct AIStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var bookmarks: [Bookmark]
    @StateObject private var aiService = AITaggingService.shared
    
    private var processedBookmarks: [Bookmark] {
        bookmarks.filter { $0.isProcessed }
    }
    
    private var unprocessedBookmarks: [Bookmark] {
        bookmarks.filter { !$0.isProcessed }
    }
    
    private var averageConfidence: Double {
        let processedWithConfidence = processedBookmarks.filter { $0.aiConfidence > 0 }
        guard !processedWithConfidence.isEmpty else { return 0.0 }
        
        let total = processedWithConfidence.reduce(0) { $0 + $1.aiConfidence }
        return total / Double(processedWithConfidence.count)
    }
    
    private var allAITags: [String] {
        let tags = processedBookmarks.flatMap { $0.aiTags }
        return Array(Set(tags)).sorted()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            overviewSection
            
            tagDistributionSection
            
            processingSection
            
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
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.visible)
    }
    
    private var headerSection: some View {
        HStack {
            Text("AI Statistics")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(CortexColors.accents.electricBlue)
        }
    }
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Processing Overview")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Processed",
                    value: "\(processedBookmarks.count)",
                    subtitle: "bookmarks",
                    color: CortexColors.accents.neonGreen
                )
                
                StatCard(
                    title: "Unprocessed",
                    value: "\(unprocessedBookmarks.count)",
                    subtitle: "remaining",
                    color: CortexColors.accents.orange
                )
                
                StatCard(
                    title: "AI Confidence",
                    value: String(format: "%.1f%%", averageConfidence * 100),
                    subtitle: "average",
                    color: CortexColors.accents.electricBlue
                )
                
                StatCard(
                    title: "AI Tags",
                    value: "\(allAITags.count)",
                    subtitle: "generated",
                    color: CortexColors.accents.vibrantPurple
                )
            }
        }
    }
    
    private var tagDistributionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Top AI Tags")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            if allAITags.isEmpty {
                Text("No AI tags generated yet")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
                    .padding(.vertical, 20)
                    .glassCard(cornerRadius: 12, shadowRadius: 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(allAITags.prefix(10)), id: \.self) { tag in
                            let count = bookmarkCountForTag(tag)
                            TagStatChip(tag: tag, count: count)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Model Status")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: aiService.isModelLoaded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(aiService.isModelLoaded ? CortexColors.accents.neonGreen : CortexColors.accents.hotPink)
                    
                    Text("DistilBERT Model")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Spacer()
                    
                    Text(aiService.isModelLoaded ? "Active" : "Loading...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.secondary)
                }
                
                if aiService.isModelLoaded {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Model Type:")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CortexColors.text.tertiary)
                            Spacer()
                            Text("DistilBERT-base")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(CortexColors.text.secondary)
                        }
                        
                        HStack {
                            Text("Compute Units:")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CortexColors.text.tertiary)
                            Spacer()
                            Text("CPU + GPU")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(CortexColors.text.secondary)
                        }
                        
                        HStack {
                            Text("Max Sequence:")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CortexColors.text.tertiary)
                            Spacer()
                            Text("512 tokens")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(CortexColors.text.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(CortexColors.glass.overlay05)
                    }
                }
                
                if aiService.isProcessing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CortexColors.accents.electricBlue))
                            .scaleEffect(0.8)
                        
                        Text("Processing with DistilBERT...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(CortexColors.text.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(aiService.processingProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(CortexColors.text.primary)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
    }
    
    private func bookmarkCountForTag(_ tag: String) -> Int {
        processedBookmarks.filter { $0.aiTags.contains(tag) }.count
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 12, shadowRadius: 8)
    }
}

struct TagStatChip: View {
    let tag: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(CortexColors.accents.electricBlue.opacity(0.2))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CortexColors.accents.electricBlue.opacity(0.3), lineWidth: 1)
                }
        }
    }
}