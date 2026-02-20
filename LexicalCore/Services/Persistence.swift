import SwiftData
import Foundation

// Centralized persistence configuration
public struct Persistence {
    public static let appGroupIdentifier = "group.com.lexical.Lexical"

    public struct StartupIssue: Identifiable, Sendable {
        public let id: UUID
        public let title: String
        public let message: String

        public init(title: String, message: String) {
            self.id = UUID()
            self.title = title
            self.message = message
        }
    }

    enum RecoveryAction: Equatable {
        case resetAndRetry
        case useInMemoryFallback
        case failFast
    }

    public private(set) static var startupIssue: StartupIssue?
    
    public static var sharedModelContainer: ModelContainer = {
        let schema = Schema(LexicalSchemaV6.models)

        startupIssue = nil

        if isRunningTests {
            let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: LexicalMigrationPlan.self,
                    configurations: [inMemoryConfiguration]
                )
            } catch {
                fatalError("Could not create in-memory test ModelContainer: \(error)")
            }
        }

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
            let recovery = recoveryAction(
                for: error,
                storeExists: FileManager.default.fileExists(atPath: storeURL.path),
                allowDestructiveReset: allowsDestructiveStoreReset
            )

            switch recovery {
            case .resetAndRetry:
                // Debug-only recovery path for legacy/incompatible stores.
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
                    startupIssue = StartupIssue(
                        title: "Storage Recovery Mode",
                        message: "Lexical could not reopen your data after a local reset attempt. Running in temporary recovery mode."
                    )
                    return makeInMemoryFallbackContainer(schema: schema, context: "post-reset load failure: \(error)")
                }

            case .useInMemoryFallback:
                startupIssue = StartupIssue(
                    title: "Storage Recovery Mode",
                    message: "Lexical could not migrate your on-device data safely. Your original data was left untouched, and the app is running in temporary recovery mode."
                )
                return makeInMemoryFallbackContainer(schema: schema, context: "migration-incompatible store: \(error)")

            case .failFast:
                fatalError("Could not create ModelContainer: \(error)")
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

    static func recoveryAction(
        for error: Error,
        storeExists: Bool,
        allowDestructiveReset: Bool
    ) -> RecoveryAction {
        guard storeExists else { return .failFast }
        guard containsIncompatibleStoreError(error) || containsIncompatibleStoreSignal(error) else {
            return .failFast
        }
        return allowDestructiveReset ? .resetAndRetry : .useInMemoryFallback
    }

    private static var allowsDestructiveStoreReset: Bool {
        #if DEBUG
        return !isRunningTests
        #else
        return false
        #endif
    }

    private static func makeInMemoryFallbackContainer(schema: Schema, context: String) -> ModelContainer {
        let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            print("⚠️ Persistence: entering in-memory recovery mode (\(context))")
            return try ModelContainer(
                for: schema,
                migrationPlan: LexicalMigrationPlan.self,
                configurations: [inMemoryConfiguration]
            )
        } catch {
            fatalError("Could not create in-memory fallback ModelContainer: \(error)")
        }
    }

    private static func containsIncompatibleStoreSignal(_ error: Error) -> Bool {
        let description = (String(describing: error) + " " + error.localizedDescription).lowercased()
        let signals = [
            "cannot use staged migration",
            "unknown model version",
            "loadissuemodelcontainer",
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

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains { argument in
            argument.localizedCaseInsensitiveContains("xctest")
        }
    }
}
