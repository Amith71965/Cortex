import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var showingFilePicker = false
    @State private var showingURLInput = false
    @State private var showingTextInput = false
    @State private var showingiCloudBackups = false
    @State private var importResult: String?
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    importOptionsSection
                    quickImportSection
                    
                    if let result = importResult {
                        resultSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Import Bookmarks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(backgroundGradient)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json, UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingURLInput) {
            URLImportView { url in
                importFromURL(url)
            }
        }
        .sheet(isPresented: $showingTextInput) {
            TextImportView { text in
                importFromText(text)
            }
        }
        .sheet(isPresented: $showingiCloudBackups) {
            ICloudBackupsView()
        }
        .alert("Import Result", isPresented: $showingResult) {
            Button("OK") { }
        } message: {
            Text(importResult ?? "")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            CortexColors.accents.neonGreen,
                            CortexColors.accents.electricBlue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Import Bookmarks")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Choose how you'd like to import your bookmarks")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var importOptionsSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(CortexColors.accents.neonGreen)
                    Text("Import from File")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    ImportOptionRow(
                        title: "Cortex Backup File",
                        description: "Import from .json or .zip backup",
                        icon: "doc.fill",
                        color: CortexColors.accents.electricBlue
                    ) {
                        showingFilePicker = true
                    }
                    
                    ImportOptionRow(
                        title: "iCloud Backups",
                        description: "Restore from previous backups",
                        icon: "icloud.fill",
                        color: CortexColors.accents.vibrantPurple
                    ) {
                        showingiCloudBackups = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var quickImportSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(CortexColors.accents.orange)
                    Text("Quick Import")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    ImportOptionRow(
                        title: "Import from URL",
                        description: "Add a single bookmark from URL",
                        icon: "link",
                        color: CortexColors.accents.electricBlue
                    ) {
                        showingURLInput = true
                    }
                    
                    ImportOptionRow(
                        title: "Import from Text",
                        description: "Paste multiple URLs or text",
                        icon: "text.alignleft",
                        color: CortexColors.accents.hotPink
                    ) {
                        showingTextInput = true
                    }
                }
            }
            .padding()
        }
    }
    
    private func resultSection(_ result: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Import Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Text(result)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Button("View Imported Bookmarks") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(CortexColors.accents.electricBlue)
                .padding(.top, 8)
            }
            .padding()
        }
    }
    
    private var backgroundGradient: some View {
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
    
    // MARK: - Import Actions
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                let importResult = await backupManager.importBookmarks(from: url, modelContext: modelContext)
                await MainActor.run {
                    switch importResult {
                    case .success(let result):
                        self.importResult = "Successfully imported \(result.imported) bookmarks. Skipped \(result.skipped) duplicates."
                        showingResult = true
                    case .failure(let error):
                        self.importResult = "Import failed: \(error.localizedDescription)"
                        showingResult = true
                    }
                }
            }
            
        case .failure(let error):
            importResult = "File selection failed: \(error.localizedDescription)"
            showingResult = true
        }
    }
    
    private func importFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            importResult = "Invalid URL format"
            showingResult = true
            return
        }
        
        let bookmark = Bookmark(
            title: url.host?.capitalized ?? "Imported Bookmark",
            url: url,
            notes: "Imported via URL"
        )
        
        modelContext.insert(bookmark)
        
        do {
            try modelContext.save()
            
            // Process with AI if enabled
            let autoOrganizeEnabled = UserDefaults.standard.bool(forKey: "autoOrganizeEnabled")
            if autoOrganizeEnabled {
                Task {
                    await AITaggingService.shared.processBookmark(bookmark, modelContext: modelContext)
                }
            }
            
            importResult = "Successfully imported 1 bookmark from URL"
            showingResult = true
        } catch {
            importResult = "Failed to save bookmark: \(error.localizedDescription)"
            showingResult = true
        }
    }
    
    private func importFromText(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var importedCount = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Try to extract URLs from the line
            if let url = extractURL(from: trimmedLine) {
                let bookmark = Bookmark(
                    title: url.host?.capitalized ?? "Imported Bookmark",
                    url: url,
                    notes: "Imported from text"
                )
                
                modelContext.insert(bookmark)
                importedCount += 1
            }
        }
        
        do {
            try modelContext.save()
            
            importResult = "Successfully imported \(importedCount) bookmarks from text"
            showingResult = true
        } catch {
            importResult = "Failed to save bookmarks: \(error.localizedDescription)"
            showingResult = true
        }
    }
    
    private func extractURL(from text: String) -> URL? {
        // Simple URL extraction - look for http/https URLs
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let url = match.url {
            return url
        }
        
        // Fallback: try to create URL directly
        return URL(string: text)
    }
}

// MARK: - Supporting Views

struct ImportOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(CortexColors.glass.overlay10)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(CortexColors.glass.overlay15, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct URLImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    let onImport: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Enter URL")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Enter the URL you'd like to bookmark")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                TextField("https://example.com", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Import") {
                    onImport(urlText)
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(CortexColors.accents.electricBlue)
                .cornerRadius(12)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                
                Spacer()
            }
            .padding()
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
            .navigationTitle("Import URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct TextImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var textContent = ""
    let onImport: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Import from Text")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Paste URLs or text containing URLs, one per line")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                TextEditor(text: $textContent)
                    .frame(minHeight: 200)
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(12)
                
                Button("Import") {
                    onImport(textContent)
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(CortexColors.accents.electricBlue)
                .cornerRadius(12)
                .disabled(textContent.trimmingCharacters(in: .whitespaces).isEmpty)
                
                Spacer()
            }
            .padding()
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
            .navigationTitle("Import Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    ImportOptionsView()
}