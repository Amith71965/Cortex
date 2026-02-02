import SwiftUI

struct AIProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var aiService: AITaggingService
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            progressSection
            
            detailsSection
            
            Spacer()
            
            if !aiService.isProcessing {
                actionButton
            }
        }
        .padding(20)
        .background {
            LinearGradient(
                colors: [
                    CortexColors.primary.deepSpace,
                    CortexColors.primary.darkBlue,
                    CortexColors.primary.mediumBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .onChange(of: aiService.isProcessing) { _, isProcessing in
            if !isProcessing && aiService.processingProgress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.secondary)
                .opacity(aiService.isProcessing ? 0.5 : 1.0)
                .disabled(aiService.isProcessing)
            }
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CortexColors.accents.vibrantPurple, CortexColors.accents.hotPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, isActive: aiService.isProcessing)
            
            VStack(spacing: 8) {
                Text("AI Tagging")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text(aiService.isProcessing ? "Analyzing your bookmarks..." : "Processing completed!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: aiService.processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: CortexColors.accents.electricBlue))
                .scaleEffect(y: 2)
                .glassCard(cornerRadius: 8, shadowRadius: 4)
                .padding(.horizontal, 4)
            
            HStack {
                Text("\(Int(aiService.processingProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Spacer()
                
                if aiService.isProcessing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CortexColors.accents.electricBlue))
                            .scaleEffect(0.6)
                        
                        Text("Processing")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(CortexColors.text.tertiary)
                    }
                } else if aiService.processingProgress >= 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CortexColors.accents.neonGreen)
                        
                        Text("Complete")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(CortexColors.accents.neonGreen)
                    }
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What's Happening?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ProcessingStep(
                        title: "Content Extraction",
                        description: "Extracting and preprocessing text from web pages",
                        isActive: aiService.processingProgress > 0.0,
                        isComplete: aiService.processingProgress > 0.2
                    )
                    
                    ProcessingStep(
                        title: "DistilBERT Analysis",
                        description: "Running neural network inference for classification",
                        isActive: aiService.processingProgress > 0.2,
                        isComplete: aiService.processingProgress > 0.6
                    )
                    
                    ProcessingStep(
                        title: "Multi-Source Tagging",
                        description: "Combining AI predictions with domain analysis",
                        isActive: aiService.processingProgress > 0.6,
                        isComplete: aiService.processingProgress > 0.8
                    )
                    
                    ProcessingStep(
                        title: "Confidence Scoring",
                        description: "Filtering and ranking generated tags",
                        isActive: aiService.processingProgress > 0.8,
                        isComplete: aiService.processingProgress >= 1.0
                    )
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
    }
    
    private var actionButton: some View {
        Button(action: {
            dismiss()
        }) {
            Text("View Updated Bookmarks")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .frame(maxWidth: .infinity)
                .padding(16)
                .glassCard(cornerRadius: 16, shadowRadius: 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProcessingStep: View {
    let title: String
    let description: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stepColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(stepColor)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: stepColor))
                        .scaleEffect(0.5)
                } else {
                    Circle()
                        .fill(CortexColors.text.tertiary)
                        .frame(width: 8, height: 8)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive || isComplete ? CortexColors.text.primary : CortexColors.text.secondary)
                
                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
            }
            
            Spacer()
        }
    }
    
    private var stepColor: Color {
        if isComplete {
            return CortexColors.accents.neonGreen
        } else if isActive {
            return CortexColors.accents.electricBlue
        } else {
            return CortexColors.text.tertiary
        }
    }
}

struct AIProcessingBanner: View {
    let progress: Double
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: CortexColors.accents.electricBlue))
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Processing")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text("\(Int(progress * 100))% complete")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 16, shadowRadius: 12)
        .padding(.horizontal, 20)
    }
}