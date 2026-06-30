import SwiftUI
import UserNotifications

@main
struct PRBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PRStore()

    var body: some Scene {
        MenuBarExtra {
            PRListView()
                .environmentObject(store)
        } label: {
            Image(systemName: "arrow.trianglehead.pull")
            if !store.reviewRequested.isEmpty {
                Text("\(store.reviewRequested.count)")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Forces the app to live only in the menu bar (no Dock icon, no main window)
/// and wires up local notifications.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        NotificationService.requestAuthorization()
    }

    /// Show the banner even while PRBar is the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Tapping a notification opens the PR.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}
