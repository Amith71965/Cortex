import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataProtectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingICloudBackups = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var exportedFileURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    iCloudSyncSection
                    backupSection
                    importExportSection
                    settingsSection
                    statusSection
                }
                .padding()
            }
            .navigationTitle("Data Protection")
            .navigationBarTitleDisplayMode(.large)
            .background(backgroundGradient)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showingICloudBackups) {
            ICloudBackupsView()
        }
        .alert("Data Protection", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .task {
            await backupManager.performAutomaticBackupIfNeeded(bookmarks)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CortexColors.accents.electricBlue, CortexColors.accents.vibrantPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Data Protection")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Keep your bookmarks safe with automatic backups and sync")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var iCloudSyncSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "icloud.fill")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.electricBlue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Automatic sync across all your devices")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Real-time Sync",
                        description: "Changes sync automatically"
                    )
                    
                    FeatureRow(
                        icon: "devices",
                        title: "All Devices",
                        description: "iPhone, iPad, Mac sync"
                    )
                    
                    FeatureRow(
                        icon: "lock.shield",
                        title: "Encrypted",
                        description: "End-to-end encryption"
                    )
                }
            }
            .padding()
        }
    }
    
    private var backupSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "externaldrive.fill.badge.icloud")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.neonGreen)
                    
                    Text("Backup & Restore")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let lastBackup = backupManager.lastBackupDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last backup")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(lastBackup, style: .relative)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: { exportBookmarks() }) {
                        HStack {
                            if backupManager.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Export")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CortexColors.accents.electricBlue)
                        .cornerRadius(10)
                    }
                    .disabled(backupManager.isExporting)
                    
                    Button(action: { exportWithImages() }) {
                        HStack {
                            if backupManager.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "photo.on.rectangle")
                            }
                            Text("With Images")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CortexColors.accents.vibrantPurple)
                        .cornerRadius(10)
                    }
                    .disabled(backupManager.isExporting)
                }
                
                Button(action: { showingICloudBackups = true }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("View iCloud Backups")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(CortexColors.accents.electricBlue)
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
    }
    
    private var importExportSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.orange)
                    
                    Text("Import & Export")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Transfer bookmarks between devices or backup to external storage")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Button(action: { showingImportPicker = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Bookmarks")
                        Spacer()
                        
                        if backupManager.isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(CortexColors.accents.orange)
                    .cornerRadius(10)
                }
                .disabled(backupManager.isImporting)
            }
            .padding()
        }
    }
    
    private var settingsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(CortexColors.accents.hotPink)
                    
                    Text("Backup Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Automatic Backup")
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { backupManager.autoBackupEnabled },
                            set: { enabled in
                                backupManager.updateSettings(
                                    autoBackup: enabled,
                                    reminderInterval: backupManager.backupReminderInterval
                                )
                            }
                        ))
                        .tint(CortexColors.accents.electricBlue)
                    }
                    
                    if backupManager.autoBackupEnabled {
                        HStack {
                            Text("Backup Frequency")
                                .foregroundColor(.white)
                            Spacer()
                            
                            Picker("Frequency", selection: Binding(
                                get: { backupManager.backupReminderInterval },
                                set: { interval in
                                    backupManager.updateSettings(
                                        autoBackup: backupManager.autoBackupEnabled,
                                        reminderInterval: interval
                                    )
                                }
                            )) {
                                ForEach(BackupReminderInterval.allCases, id: \.self) { interval in
                                    Text(interval.displayName).tag(interval)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(CortexColors.accents.electricBlue)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var statusSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(CortexColors.accents.electricBlue)
                    Text("Protection Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    StatusRow(
                        title: "Total Bookmarks",
                        value: "\(bookmarks.count)",
                        icon: "bookmark.fill",
                        status: .info
                    )
                    
                    StatusRow(
                        title: "iCloud Sync",
                        value: "Active",
                        icon: "icloud.fill",
                        status: .success
                    )
                    
                    StatusRow(
                        title: "Auto Backup",
                        value: backupManager.autoBackupEnabled ? "Enabled" : "Disabled",
                        icon: "externaldrive.fill",
                        status: backupManager.autoBackupEnabled ? .success : .warning
                    )
                    
                    if let lastBackup = backupManager.lastBackupDate {
                        StatusRow(
                            title: "Last Backup",
                            value: lastBackup.formatted(date: .abbreviated, time: .shortened),
                            icon: "clock.fill",
                            status: .info
                        )
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
                CortexColors.primary.darkBlue,
                CortexColors.primary.mediumBlue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Actions
    
    private func exportBookmarks() {
        Task {
            let result = await backupManager.exportBookmarks(bookmarks)
            await MainActor.run {
                switch result {
                case .success(let url):
                    exportedFileURL = url
                    showingExportSheet = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func exportWithImages() {
        Task {
            let result = await backupManager.exportBookmarksWithImages(bookmarks)
            await MainActor.run {
                switch result {
                case .success(let url):
                    exportedFileURL = url
                    showingExportSheet = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                let importResult = await backupManager.importBookmarks(from: url, modelContext: modelContext)
                await MainActor.run {
                    switch importResult {
                    case .success(let result):
                        alertMessage = "Successfully imported \(result.imported) bookmarks. Skipped \(result.skipped) duplicates."
                        showingAlert = true
                    case .failure(let error):
                        alertMessage = error.localizedDescription
                        showingAlert = true
                    }
                }
            }
            
        case .failure(let error):
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(CortexColors.accents.electricBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let icon: String
    let status: StatusType
    
    enum StatusType {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return CortexColors.accents.electricBlue
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(status.color)
                .frame(width: 16)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, Tag.self, configurations: config)
        
        return DataProtectionView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error")
    }
}