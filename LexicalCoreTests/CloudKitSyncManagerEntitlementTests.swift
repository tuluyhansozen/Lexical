import XCTest
@testable import LexicalCore

final class CloudKitSyncManagerEntitlementTests: XCTestCase {
    func testCloudKitEntitlementEnabledReturnsTrueForCloudKitServiceWithContainer() {
        let enabled = CloudKitSyncManager.cloudKitEntitlementEnabled(
            cloudKitServices: ["CloudKit"],
            containers: ["iCloud.com.lexical.app"]
        )

        XCTAssertTrue(enabled)
    }

    func testCloudKitEntitlementEnabledReturnsFalseWithoutCloudKitService() {
        let enabled = CloudKitSyncManager.cloudKitEntitlementEnabled(
            cloudKitServices: ["CloudDocuments"],
            containers: ["iCloud.com.lexical.app"]
        )

        XCTAssertFalse(enabled)
    }

    func testCloudKitEntitlementEnabledReturnsFalseWithoutContainer() {
        let enabled = CloudKitSyncManager.cloudKitEntitlementEnabled(
            cloudKitServices: ["CloudKit"],
            containers: nil
        )

        XCTAssertFalse(enabled)
    }
}
