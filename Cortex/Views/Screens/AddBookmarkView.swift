import SwiftUI
import SwiftData

struct AddBookmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @StateObject private var aiService = AITaggingService.shared
    
    @State private var urlString = ""
    @State private var title = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var showingTagInput = false
    @State private var errorMessage = ""
    
    private var allExistingTags: [String] {
        let tagSet = Set(bookmarks.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }
    
    private var isValidInput: Bool {
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    urlSection
                    
                    titleSection
                    
                    tagsSection
                    
                    notesSection
                    
                    if !errorMessage.isEmpty {
                        errorSection
                    }
                    
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
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
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
    
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(CortexColors.text.secondary)
            
            Spacer()
            
            Text("Add Bookmark")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            Spacer()
            
            Button("Save") {
                saveBookmark()
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(isValidInput ? CortexColors.accents.electricBlue : CortexColors.text.tertiary)
            .disabled(!isValidInput || isLoading)
        }
    }
    
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URL")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            TextField("https://example.com", text: $urlString)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(16)
                .glassCard(cornerRadius: 12, shadowRadius: 8)
                .onChange(of: urlString) { _, newValue in
                    if !newValue.isEmpty && !title.isEmpty {
                        // Auto-fetch title if URL looks valid
                        fetchTitleFromURL()
                    }
                }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Title")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            TextField("Bookmark title", text: $title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .padding(16)
                .glassCard(cornerRadius: 12, shadowRadius: 8)
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Spacer()
                
                Button(action: {
                    showingTagInput = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CortexColors.accents.electricBlue)
                }
            }
            
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(
                                text: tag,
                                size: .medium,
                                onTap: {
                                    selectedTags.remove(tag)
                                    HapticManager.shared.impact(.light)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            if !allExistingTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Tags")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allExistingTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                                TagChip(
                                    text: tag,
                                    color: CortexColors.glass.overlay20,
                                    size: .small,
                                    onTap: {
                                        selectedTags.insert(tag)
                                        HapticManager.shared.impact(.light)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagInput) {
            AddTagView(onTagAdded: { tag in
                selectedTags.insert(tag)
            })
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            
            TextField("Add personal notes...", text: $notes, axis: .vertical)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .lineLimit(3...6)
                .padding(16)
                .glassCard(cornerRadius: 12, shadowRadius: 8)
        }
    }
    
    private var errorSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(CortexColors.accents.hotPink)
            
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.accents.hotPink)
            
            Spacer()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(CortexColors.accents.hotPink.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(CortexColors.accents.hotPink.opacity(0.3), lineWidth: 1)
                }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                saveBookmark()
            }) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CortexColors.text.primary))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save Bookmark")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(CortexColors.text.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .glassCard(cornerRadius: 16, shadowRadius: 15)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isValidInput || isLoading)
            .opacity(!isValidInput || isLoading ? 0.6 : 1.0)
            
            Button(action: {
                fetchTitleFromURL()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Auto-fill Title")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(CortexColors.text.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(urlString.isEmpty || isLoading)
        }
    }
    
    private func fetchTitleFromURL() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        
        isLoading = true
        errorMessage = ""
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to fetch page title: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    errorMessage = "Unable to read page content"
                    return
                }
                
                // Simple title extraction
                if let titleRange = html.range(of: "<title>"),
                   let endRange = html.range(of: "</title>", range: titleRange.upperBound..<html.endIndex) {
                    let extractedTitle = String(html[titleRange.upperBound..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !extractedTitle.isEmpty && title.isEmpty {
                        title = extractedTitle
                    }
                }
            }
        }.resume()
    }
    
    private func saveBookmark() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let bookmark = Bookmark(
            title: trimmedTitle,
            url: url,
            tags: Array(selectedTags),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(bookmark)
        
        do {
            try modelContext.save()
            
            // Automatically process with AI if enabled
            let autoOrganizeEnabled = UserDefaults.standard.bool(forKey: "autoOrganizeEnabled")
            if autoOrganizeEnabled {
                Task {
                    await aiService.processBookmark(bookmark, modelContext: modelContext)
                }
            }
            
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            isLoading = false
            errorMessage = "Failed to save bookmark: \(error.localizedDescription)"
            HapticManager.shared.notification(.error)
        }
    }
}

struct AddTagView: View {
    @Environment(\.dismiss) private var dismiss
    let onTagAdded: (String) -> Void
    
    @State private var tagName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Add New Tag")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.secondary)
            }
            
            TextField("Tag name", text: $tagName)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
                .padding(16)
                .glassCard(cornerRadius: 12, shadowRadius: 8)
                .onSubmit {
                    addTag()
                }
            
            Button(action: {
                addTag()
            }) {
                Text("Add Tag")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .glassCard(cornerRadius: 16, shadowRadius: 12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            
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
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
    }
    
    private func addTag() {
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        onTagAdded(trimmedTag)
        dismiss()
    }
}