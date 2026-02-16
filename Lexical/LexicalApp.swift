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

                let report = await CloudKitSyncManager.shared.synchronize(
                    modelContainer: Persistence.sharedModelContainer
                )
                print("CloudKit sync: \(report.message)")
            }
    }
}
