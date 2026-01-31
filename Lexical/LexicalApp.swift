import SwiftUI
import SwiftData
import LexicalCore

@main
struct LexicalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Persistence.sharedModelContainer)
    }
}
