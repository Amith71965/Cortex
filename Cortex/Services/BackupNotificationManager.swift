import Foundation
import UserNotifications
import SwiftData

/// Manages backup reminder notifications
class BackupNotificationManager: ObservableObject {
    static let shared = BackupNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let backupReminderIdentifier = "cortex.backup.reminder"
    
    private init() {}
    
    // MARK: - Notification Permission
    
    /// Request notification permission
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Check current notification permission status
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Backup Reminders
    
    /// Schedule backup reminder notifications
    func scheduleBackupReminder(interval: BackupReminderInterval) async {
        // Remove existing reminders
        await removeBackupReminders()
        
        // Check permission
        let hasPermission = await requestNotificationPermission()
        guard hasPermission else {
            print("⚠️ Notification permission denied - backup reminders disabled")
            return
        }
        
        // Create reminder content
        let content = UNMutableNotificationContent()
        content.title = "Backup Reminder"
        content.body = "Don't forget to backup your bookmarks to keep them safe!"
        content.sound = .default
        content.badge = 1
        
        // Add action buttons
        let backupAction = UNNotificationAction(
            identifier: "backup.now",
            title: "Backup Now",
            options: [.foreground]
        )
        
        let laterAction = UNNotificationAction(
            identifier: "backup.later",
            title: "Remind Me Later",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "backup.reminder",
            actions: [backupAction, laterAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([category])
        content.categoryIdentifier = "backup.reminder"
        
        // Schedule recurring reminder
        let timeInterval = interval.timeInterval
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: backupReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ Backup reminder scheduled for every \(interval.displayName.lowercased())")
        } catch {
            print("❌ Failed to schedule backup reminder: \(error)")
        }
    }
    
    /// Remove all backup reminder notifications
    func removeBackupReminders() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [backupReminderIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [backupReminderIdentifier])
        print("🗑️ Backup reminders removed")
    }
    
    // MARK: - Immediate Notifications
    
    /// Send backup success notification
    func sendBackupSuccessNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Backup Complete"
        content.body = "Your bookmarks have been safely backed up to iCloud."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "backup.success.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send backup success notification: \(error)")
        }
    }
    
    /// Send backup failure notification
    func sendBackupFailureNotification(_ error: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Backup Failed"
        content.body = "Unable to backup your bookmarks: \(error)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "backup.failure.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send backup failure notification: \(error)")
        }
    }
    
    /// Send low storage warning
    func sendStorageWarningNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Storage Warning"
        content.body = "Cortex is using significant storage. Consider optimizing your data."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "storage.warning.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send storage warning notification: \(error)")
        }
    }
    
    // MARK: - Notification Response Handling
    
    /// Handle notification responses (when user taps actions)
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case "backup.now":
            await triggerBackupFromNotification()
            
        case "backup.later":
            await scheduleOneTimeReminder(in: 3600) // 1 hour later
            
        default:
            break
        }
    }
    
    private func triggerBackupFromNotification() async {
        // This would trigger the backup process
        // Implementation would depend on app architecture
        print("🔄 Backup triggered from notification")
        
        // For now, we'll just log - actual implementation would:
        // 1. Get bookmarks from SwiftData
        // 2. Call BackupManager.shared.exportBookmarks()
        // 3. Save to iCloud Drive
        // 4. Send success/failure notification
    }
    
    private func scheduleOneTimeReminder(in seconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = "Backup Reminder"
        content.body = "Time to backup your bookmarks!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "backup.later.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule later reminder: \(error)")
        }
    }
    
    // MARK: - Utility
    
    /// Get pending notification count
    func getPendingNotificationsCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
    
    /// Clear all notifications
    func clearAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - Extensions

extension BackupReminderInterval {
    var timeInterval: TimeInterval {
        switch self {
        case .daily:
            return 24 * 60 * 60 // 24 hours
        case .weekly:
            return 7 * 24 * 60 * 60 // 7 days
        case .monthly:
            return 30 * 24 * 60 * 60 // 30 days
        }
    }
}

// MARK: - App Delegate Integration

/// Add this to your App Delegate or main app file to handle notification responses
public class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await BackupNotificationManager.shared.handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}