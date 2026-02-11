import SwiftUI
import SwiftData
import LexicalCore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = BanditScheduler.shared
        return true
    }
    
    // Show in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        BanditScheduler.shared.handleNotificationResponse(response)
        completionHandler()
    }
}

@main
struct LexicalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var banditScheduler = BanditScheduler.shared
    @StateObject private var motionService = MotionService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(banditScheduler)
                .environmentObject(motionService)
        }
        .modelContainer(Persistence.sharedModelContainer)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didRunBootstrapTasks = false

    var body: some View {
        ContentView()
            .task {
                guard !didRunBootstrapTasks else { return }
                didRunBootstrapTasks = true

                // Use new VocabularySeeder for 5000-entry seed_data.json
                await VocabularySeeder.shared.seed(modelContainer: Persistence.sharedModelContainer)

                let report = await CloudKitSyncManager.shared.synchronize(
                    modelContainer: Persistence.sharedModelContainer
                )
                print("CloudKit sync: \(report.message)")
            }
    }
}
