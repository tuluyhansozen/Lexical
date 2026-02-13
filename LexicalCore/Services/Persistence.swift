import SwiftData
import Foundation

// Centralized persistence configuration
public struct Persistence {
    public static let appGroupIdentifier = "group.com.lexical.Lexical"
    
    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema(LexicalSchemaV6.models)

        let storeURL: URL

        // Try to use App Group container, fallback to standard documents if unavailable (e.g. simulator without entitlements)
        if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            storeURL = sharedURL.appendingPathComponent("Lexical.sqlite")
            print("💾 Persistence: Using App Group container at \(storeURL.path)")
        } else {
            // Fallback for development/simulator if App Groups aren't set up
            storeURL = URL.documentsDirectory.appendingPathComponent("Lexical.sqlite")
            print("💾 Persistence: Using standard Documents container at \(storeURL.path)")
        }

        let modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: LexicalMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            guard shouldAttemptStoreReset(for: error, storeURL: storeURL) else {
                fatalError("Could not create ModelContainer: \(error)")
            }

            // Recovery path for legacy/incompatible stores that cannot be staged-migrated.
            print("⚠️ Persistence: initial model-container load failed: \(error)")
            print("⚠️ Persistence: attempting store reset at \(storeURL.path)")
            backupAndRemoveStore(at: storeURL)

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: LexicalMigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not recreate ModelContainer after store reset: \(error)")
            }
        }
    }()

    private static func backupAndRemoveStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = storeURL.deletingPathExtension().appendingPathExtension("backup-\(timestamp).sqlite")

        if fileManager.fileExists(atPath: storeURL.path) {
            do {
                try fileManager.copyItem(at: storeURL, to: backupURL)
                print("💾 Persistence: backed up legacy store to \(backupURL.path)")
            } catch {
                print("⚠️ Persistence: failed to back up legacy store: \(error)")
            }
        }

        let sidecars = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for url in sidecars where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                print("⚠️ Persistence: failed to remove \(url.lastPathComponent): \(error)")
            }
        }
    }

    private static func shouldAttemptStoreReset(for error: Error, storeURL: URL) -> Bool {
        // Never reset if no on-disk store exists yet.
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return false }

        if containsIncompatibleStoreError(error) {
            return true
        }

        // SwiftData may wrap CoreData errors. Fall back to string signals to avoid
        // false negatives for known migration incompatibilities.
        let description = (String(describing: error) + " " + error.localizedDescription).lowercased()
        let signals = [
            "cannot use staged migration",
            "unknown model version",
            "incompatible",
            "134504",
            "134130",
            "134110",
            "134100"
        ]

        return signals.contains { description.contains($0) }
    }

    private static func containsIncompatibleStoreError(_ error: Error) -> Bool {
        let knownCodes: Set<Int> = [134504, 134130, 134110, 134100]

        func visit(_ nsError: NSError) -> Bool {
            if nsError.domain == NSCocoaErrorDomain && knownCodes.contains(nsError.code) {
                return true
            }

            for value in nsError.userInfo.values {
                if let nested = value as? NSError, visit(nested) {
                    return true
                }

                if let nestedArray = value as? [NSError], nestedArray.contains(where: visit) {
                    return true
                }
            }

            return false
        }

        return visit(error as NSError)
    }
}
