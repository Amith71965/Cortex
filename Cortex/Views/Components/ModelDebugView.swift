import SwiftUI

struct ModelDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AITaggingService.shared
    @State private var modelInfo: (isLoaded: Bool, modelPath: String?, inputNames: [String], outputNames: [String]) = (false, nil, [], [])
    @State private var testText = "This is a sample technology article about programming and software development."
    @State private var testResults: [ClassificationResult] = []
    @State private var isTestingModel = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            modelInfoSection
            
            testingSection
            
            if !testResults.isEmpty {
                resultsSection
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
        .onAppear {
            loadModelInfo()
        }
        .presentationDetents([.height(700)])
        .presentationDragIndicator(.visible)
    }
    
    private var headerSection: some View {
        HStack {
            Text("DistilBERT Debug")
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
    
    private var modelInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Model Information")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "Status", value: modelInfo.isLoaded ? "✅ Loaded" : "❌ Not Loaded")
                
                if let path = modelInfo.modelPath {
                    InfoRow(title: "Path", value: path.components(separatedBy: "/").last ?? "Unknown")
                }
                
                if !modelInfo.inputNames.isEmpty {
                    InfoRow(title: "Inputs", value: modelInfo.inputNames.joined(separator: ", "))
                }
                
                if !modelInfo.outputNames.isEmpty {
                    InfoRow(title: "Outputs", value: modelInfo.outputNames.joined(separator: ", "))
                }
                
                InfoRow(title: "AI Service", value: aiService.isModelLoaded ? "✅ Ready" : "⏳ Loading")
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
    }
    
    private var testingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Model Testing")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Text("Test Text:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Enter text to classify...", text: $testText, axis: .vertical)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .lineLimit(3...6)
                    .padding(12)
                    .glassCard(cornerRadius: 12, shadowRadius: 8)
                
                Button(action: {
                    testModel()
                }) {
                    HStack(spacing: 8) {
                        if isTestingModel {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: CortexColors.text.primary))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Text(isTestingModel ? "Testing..." : "Test Model")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(CortexColors.text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .glassCard(cornerRadius: 12, shadowRadius: 12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTestingModel || testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isTestingModel || testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Classification Results")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(testResults.indices, id: \.self) { index in
                    let result = testResults[index]
                    
                    HStack {
                        Text(result.category)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(CortexColors.text.primary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", result.confidence * 100))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(CortexColors.text.secondary)
                        
                        // Confidence bar
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(CortexColors.glass.overlay10)
                                .frame(width: 60, height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(CortexColors.accents.electricBlue)
                                .frame(width: 60 * result.confidence, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
    }
    
    private func loadModelInfo() {
        let coreMLLoader = CoreMLModelLoader.shared
        modelInfo = coreMLLoader.getModelInfo()
    }
    
    private func testModel() {
        guard !testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isTestingModel = true
        testResults = []
        
        Task {
            let coreMLLoader = CoreMLModelLoader.shared
            let results = await coreMLLoader.classifyText(testText)
            
            await MainActor.run {
                testResults = results
                isTestingModel = false
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}