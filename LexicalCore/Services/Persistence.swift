import SwiftData
import Foundation

// Centralized persistence configuration
public struct Persistence {
    public static let appGroupIdentifier = "group.com.lexical.Lexical"
    
    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabularyItem.self,
            ReviewLog.self,
            MorphologicalRoot.self
        ])
        
        let modelConfiguration: ModelConfiguration
        
        // Try to use App Group container, fallback to standard documents if unavailable (e.g. simulator without entitlements)
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = sharedURL.appendingPathComponent("Lexical.sqlite")
            modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
            print("💾 Persistence: Using App Group container at \(storeURL.path)")
        } else {
            // Fallback for development/simulator if App Groups aren't set up
            let storeURL = URL.documentsDirectory.appendingPathComponent("Lexical.sqlite")
            modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
            print("💾 Persistence: Using standard Documents container at \(storeURL.path)")
        }
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
