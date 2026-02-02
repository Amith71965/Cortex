import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @State private var showingClearDataAlert = false
    @State private var showingExportOptions = false
    @State private var showingAbout = false
    @State private var showingAIStats = false
    @State private var showingModelDebug = false
    @State private var showingDataProtection = false
    @State private var showingStorageManagement = false
    @State private var showingAuthentication = false
    
    // Settings toggles
    @State private var notificationsEnabled = true
    @State private var autoOrganizeEnabled = false
    @State private var darkModeEnabled = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                generalSection
                
                dataSection
                
                aboutSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all bookmarks and tags. This action cannot be undone.")
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingAIStats) {
            AIStatsView()
        }
        .sheet(isPresented: $showingModelDebug) {
            ModelDebugView()
        }
        .sheet(isPresented: $showingDataProtection) {
            DataProtectionView()
        }
        .sheet(isPresented: $showingStorageManagement) {
            StorageManagementView()
        }
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationSettingsView()
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                
                Text("Customize your experience")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.tertiary)
            }
            
            Spacer()
        }
    }
    
    private var generalSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "General")
            
            VStack(spacing: 12) {
                SettingsRow(
                    title: "Account & Security",
                    icon: "person.crop.circle.fill",
                    showChevron: true
                ) {
                    showingAuthentication = true
                }
                
                SettingsRow(
                    title: "Notifications",
                    icon: "bell",
                    trailing: AnyView(
                        Toggle("", isOn: $notificationsEnabled)
                            .tint(CortexColors.accents.electricBlue)
                            .onChange(of: notificationsEnabled) { _, newValue in
                                handleNotificationToggle(newValue)
                            }
                    )
                )
                
                SettingsRow(
                    title: "Auto-organize with AI",
                    icon: "brain.head.profile",
                    trailing: AnyView(
                        Toggle("", isOn: $autoOrganizeEnabled)
                            .tint(CortexColors.accents.vibrantPurple)
                            .onChange(of: autoOrganizeEnabled) { _, newValue in
                                handleAutoOrganizeToggle(newValue)
                            }
                    )
                )
                
                SettingsRow(
                    title: "AI Statistics",
                    icon: "chart.bar.fill",
                    showChevron: true
                ) {
                    showingAIStats = true
                }
                
                SettingsRow(
                    title: "Model Debug",
                    icon: "ladybug.fill",
                    showChevron: true
                ) {
                    showingModelDebug = true
                }
                
                SettingsRow(
                    title: "Dark Mode",
                    icon: "moon.fill",
                    trailing: AnyView(
                        Toggle("", isOn: $darkModeEnabled)
                            .tint(CortexColors.accents.hotPink)
                            .onChange(of: darkModeEnabled) { _, newValue in
                                handleDarkModeToggle(newValue)
                            }
                    )
                )
            }
        }
    }
    
    private var dataSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Data Management")
            
            VStack(spacing: 12) {
                SettingsRow(
                    title: "Export Bookmarks",
                    icon: "square.and.arrow.up",
                    showChevron: true
                ) {
                    showingExportOptions = true
                }
                
                SettingsRow(
                    title: "Data Protection",
                    icon: "shield.lefthalf.filled",
                    showChevron: true
                ) {
                    showingDataProtection = true
                }
                
                SettingsRow(
                    title: "Storage Management",
                    icon: "internaldrive",
                    showChevron: true
                ) {
                    showingStorageManagement = true
                }
                
                SettingsRow(
                    title: "Import Bookmarks",
                    icon: "square.and.arrow.down",
                    showChevron: true
                ) {
                    showingDataProtection = true
                }
                
                SettingsRow(
                    title: "Clear All Data",
                    icon: "trash",
                    isDestructive: true
                ) {
                    showingClearDataAlert = true
                }
            }
        }
    }
    
    private var aboutSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "About")
            
            VStack(spacing: 12) {
                SettingsRow(
                    title: "App Version",
                    icon: "info.circle",
                    trailing: AnyView(
                        Text("1.0.0")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(CortexColors.text.tertiary)
                    )
                )
                
                SettingsRow(
                    title: "About Cortex",
                    icon: "questionmark.circle",
                    showChevron: true
                ) {
                    showingAbout = true
                }
                
                SettingsRow(
                    title: "Privacy Policy",
                    icon: "hand.raised",
                    showChevron: true
                ) {
                    // TODO: Open privacy policy
                }
                
                SettingsRow(
                    title: "Terms of Service",
                    icon: "doc.text",
                    showChevron: true
                ) {
                    // TODO: Open terms of service
                }
            }
        }
    }
    
    private func clearAllData() {
        // Clear all bookmarks
        for bookmark in bookmarks {
            modelContext.delete(bookmark)
        }
        
        do {
            try modelContext.save()
            HapticManager.shared.notification(.success)
        } catch {
            HapticManager.shared.notification(.error)
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // Load saved preferences with defaults
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        autoOrganizeEnabled = UserDefaults.standard.object(forKey: "autoOrganizeEnabled") as? Bool ?? false
        darkModeEnabled = UserDefaults.standard.object(forKey: "darkModeEnabled") as? Bool ?? true
        
        print("📱 Loaded settings - Notifications: \(notificationsEnabled), Auto-organize: \(autoOrganizeEnabled), Dark mode: \(darkModeEnabled)")
    }
    
    // MARK: - Toggle Handlers
    
    private func handleNotificationToggle(_ enabled: Bool) {
        print("🔔 Notifications \(enabled ? "enabled" : "disabled")")
        
        if enabled {
            // Request notification permission
            Task {
                let granted = await BackupNotificationManager.shared.requestNotificationPermission()
                await MainActor.run {
                    if !granted {
                        // If permission denied, revert toggle
                        notificationsEnabled = false
                        HapticManager.shared.notification(.error)
                    } else {
                        HapticManager.shared.notification(.success)
                        // Enable backup reminders
                        BackupManager.shared.scheduleBackupReminders()
                    }
                }
            }
        } else {
            // Disable notifications
            Task {
                await BackupNotificationManager.shared.removeBackupReminders()
                await MainActor.run {
                    HapticManager.shared.notification(.success)
                }
            }
        }
        
        // Save preference
        UserDefaults.standard.set(enabled, forKey: "notificationsEnabled")
    }
    
    private func handleAutoOrganizeToggle(_ enabled: Bool) {
        print("🤖 Auto-organize \(enabled ? "enabled" : "disabled")")
        
        if enabled {
            // Start auto-organizing new bookmarks
            HapticManager.shared.notification(.success)
            
            // Process any unprocessed bookmarks
            Task {
                let unprocessedBookmarks = bookmarks.filter { !$0.isProcessed }
                if !unprocessedBookmarks.isEmpty {
                    await AITaggingService.shared.processMultipleBookmarks(unprocessedBookmarks, modelContext: modelContext)
                }
            }
        } else {
            HapticManager.shared.notification(.success)
        }
        
        // Save preference
        UserDefaults.standard.set(enabled, forKey: "autoOrganizeEnabled")
    }
    
    private func handleDarkModeToggle(_ enabled: Bool) {
        print("🌙 Dark mode \(enabled ? "enabled" : "disabled")")
        HapticManager.shared.notification(.success)
        
        // Note: In a real implementation, you would update the app's color scheme
        // For now, this is just a visual toggle since the app is already dark-themed
        
        // Save preference
        UserDefaults.standard.set(enabled, forKey: "darkModeEnabled")
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(CortexColors.text.primary)
            Spacer()
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    let trailing: AnyView?
    let showChevron: Bool
    let isDestructive: Bool
    let action: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        title: String,
        icon: String,
        trailing: AnyView? = nil,
        showChevron: Bool = false,
        isDestructive: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.trailing = trailing
        self.showChevron = showChevron
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: {
                    action()
                    HapticManager.shared.impact(.light)
                }) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(
                    minimumDuration: 0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = pressing
                        }
                    },
                    perform: {}
                )
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDestructive ? CortexColors.accents.hotPink : CortexColors.accents.electricBlue)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(isDestructive ? CortexColors.accents.hotPink : CortexColors.text.primary)
            
            Spacer()
            
            if let trailing = trailing {
                trailing
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CortexColors.text.tertiary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, shadowRadius: isPressed ? 5 : 12)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Export Options")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.secondary)
            }
            
            VStack(spacing: 12) {
                ExportOptionRow(
                    title: "JSON Format",
                    description: "Complete data with tags and metadata",
                    icon: "doc.text"
                ) {
                    // TODO: Export as JSON
                    dismiss()
                }
                
                ExportOptionRow(
                    title: "HTML Bookmarks",
                    description: "Standard browser-compatible format",
                    icon: "globe"
                ) {
                    // TODO: Export as HTML
                    dismiss()
                }
                
                ExportOptionRow(
                    title: "CSV File",
                    description: "Spreadsheet-compatible format",
                    icon: "tablecells"
                ) {
                    // TODO: Export as CSV
                    dismiss()
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
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
    }
}

struct ExportOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(CortexColors.accents.electricBlue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text(description)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CortexColors.text.tertiary)
            }
            .padding(16)
            .glassCard(cornerRadius: 16, shadowRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("About Cortex")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(CortexColors.text.primary)
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.accents.electricBlue)
            }
            
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CortexColors.accents.electricBlue, CortexColors.accents.vibrantPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text("Cortex")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(CortexColors.text.primary)
                    
                    Text("Version 1.0.0")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(CortexColors.text.tertiary)
                }
                
                Text("A modern bookmark manager with AI-powered organization and glassmorphism design. Save, organize, and discover your bookmarks with intelligent tagging and beautiful interfaces.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(CortexColors.text.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            Spacer()
            
            Text("Made with ❤️ using SwiftUI")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(CortexColors.text.tertiary)
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
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
    }
}