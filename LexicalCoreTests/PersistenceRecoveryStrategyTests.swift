import XCTest
@testable import LexicalCore

final class PersistenceRecoveryStrategyTests: XCTestCase {
    private struct SwiftDataLoadIssueError: Error, CustomStringConvertible, LocalizedError {
        var description: String {
            "SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer, _explanation: nil)"
        }

        var errorDescription: String? {
            "The operation couldn’t be completed. (SwiftData.SwiftDataError error 1.)"
        }
    }

    func testIncompatibleStoreAllowsResetInDebugPath() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 134504)

        let action = Persistence.recoveryAction(
            for: error,
            storeExists: true,
            allowDestructiveReset: true
        )

        XCTAssertEqual(action, .resetAndRetry)
    }

    func testIncompatibleStoreUsesInMemoryFallbackWhenResetDisabled() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 134130)

        let action = Persistence.recoveryAction(
            for: error,
            storeExists: true,
            allowDestructiveReset: false
        )

        XCTAssertEqual(action, .useInMemoryFallback)
    }

    func testNoStoreAlwaysFailsFast() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 134100)

        let action = Persistence.recoveryAction(
            for: error,
            storeExists: false,
            allowDestructiveReset: true
        )

        XCTAssertEqual(action, .failFast)
    }

    func testNonIncompatibleErrorFailsFast() {
        let error = NSError(domain: "test.error", code: 999)

        let action = Persistence.recoveryAction(
            for: error,
            storeExists: true,
            allowDestructiveReset: true
        )

        XCTAssertEqual(action, .failFast)
    }

    func testLoadIssueModelContainerSignalUsesRecoveryPath() {
        let action = Persistence.recoveryAction(
            for: SwiftDataLoadIssueError(),
            storeExists: true,
            allowDestructiveReset: true
        )

        XCTAssertEqual(action, .resetAndRetry)
    }
}
