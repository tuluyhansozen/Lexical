import SwiftUI
import SwiftData
import LexicalCore
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = BanditScheduler.shared
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        BanditScheduler.shared.syncOutOfAppReminderNotifications(notificationsEnabled: notificationsEnabled)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        BanditScheduler.shared.syncOutOfAppReminderNotifications(notificationsEnabled: notificationsEnabled)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        BanditScheduler.shared.syncOutOfAppReminderNotifications(notificationsEnabled: notificationsEnabled)
    }
    
    // Suppress app-owned reminder/ready notifications while foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let category = notification.request.content.categoryIdentifier
        if BanditScheduler.foregroundSuppressedCategories.contains(category) {
            completionHandler([])
            return
        }
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
#endif

@main
struct LexicalApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var banditScheduler = BanditScheduler.shared
    @StateObject private var motionService = MotionService()

    init() {
        E2ETestLaunchConfigurator.configureIfNeeded()
    }
    
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
    @State private var didRunBootstrapTasks = false
    @State private var didScheduleDeferredCloudSync = false
    @State private var persistenceStartupIssue: Persistence.StartupIssue? = Persistence.startupIssue
    @AppStorage(OnboardingStorageKeys.completed) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingFlowView {
                    hasCompletedOnboarding = true
                }
            }
        }
            .task {
                guard !didRunBootstrapTasks else { return }
                didRunBootstrapTasks = true

                if E2ETestLaunchConfigurator.shouldSkipBootstrapTasks {
                    return
                }

                let premiumProductIDs = SubscriptionEntitlementService.configuredProductIDs()
                _ = await SubscriptionEntitlementService.shared.bootstrap(
                    modelContainer: Persistence.sharedModelContainer,
                    productIDs: premiumProductIDs
                )

                // Use new VocabularySeeder for 5000-entry seed_data.json
                await VocabularySeeder.shared.seed(modelContainer: Persistence.sharedModelContainer)
                SeedLexemeIndex.prewarm()
            }
            .task(id: didRunBootstrapTasks) {
                guard didRunBootstrapTasks else { return }
                guard !E2ETestLaunchConfigurator.shouldSkipBootstrapTasks else { return }
                guard !didScheduleDeferredCloudSync else { return }
                didScheduleDeferredCloudSync = true

                Task.detached(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let report = await CloudKitSyncManager.shared.synchronizeSharedContainer()
                    print("CloudKit sync: \(report.message)")
                }
            }
            .onAppear {
                if persistenceStartupIssue == nil {
                    persistenceStartupIssue = Persistence.startupIssue
                }
            }
            .alert(item: $persistenceStartupIssue) { issue in
                Alert(
                    title: Text(issue.title),
                    message: Text(issue.message),
                    dismissButton: .default(Text("Continue"))
                )
            }
    }
}
