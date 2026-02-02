import SwiftUI
import SwiftData

struct ICloudBackupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var backupFiles: [BackupFile] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var selectedFile: BackupFile?
    @State private var showingRestoreConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if backupFiles.isEmpty {
                    emptyStateView
                } else {
                    backupListView
                }
            }
            .navigationTitle("iCloud Backups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadBackups()
                    }
                    .disabled(isLoading)
                }
            }
            .background(backgroundGradient)
            .task {
                loadBackups()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Restore Backup", isPresented: $showingRestoreConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    if let file = selectedFile {
                        restoreBackup(file)
                    }
                }
            } message: {
                Text("This will import bookmarks from the selected backup. Existing bookmarks will not be deleted.")
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(CortexColors.accents.electricBlue)
            
            Text("Loading iCloud backups...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Backups Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Create your first backup to see it here")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Backup Now") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(CortexColors.accents.electricBlue)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var backupListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(backupFiles, id: \.url) { file in
                    BackupFileCard(file: file) {
                        selectedFile = file
                        showingRestoreConfirmation = true
                    }
                }
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
    
    private func loadBackups() {
        isLoading = true
        Task {
            let result = await backupManager.listICloudBackups()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let files):
                    backupFiles = files
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func restoreBackup(_ file: BackupFile) {
        Task {
            let result = await backupManager.importBookmarks(from: file.url, modelContext: modelContext)
            await MainActor.run {
                switch result {
                case .success(let importResult):
                    errorMessage = "Successfully restored \(importResult.imported) bookmarks from backup."
                    showingError = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct BackupFileCard: View {
    let file: BackupFile
    let onRestore: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(file.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatFileSize(file.size))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Image(systemName: file.isDownloaded ? "checkmark.icloud.fill" : "icloud.and.arrow.down")
                                .font(.caption)
                                .foregroundColor(file.isDownloaded ? .green : .orange)
                            
                            Text(file.isDownloaded ? "Downloaded" : "In Cloud")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                HStack {
                    Button("Download") {
                        downloadFile()
                    }
                    .font(.subheadline)
                    .foregroundColor(CortexColors.accents.electricBlue)
                    .disabled(file.isDownloaded)
                    
                    Spacer()
                    
                    Button("Restore") {
                        onRestore()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(CortexColors.accents.vibrantPurple)
                    .cornerRadius(8)
                    .disabled(!file.isDownloaded)
                }
            }
            .padding()
        }
    }
    
    private func downloadFile() {
        Task {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: file.url)
            } catch {
                print("Failed to download file: \(error)")
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    ICloudBackupsView()
}