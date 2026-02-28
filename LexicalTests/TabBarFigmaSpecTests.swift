import XCTest
@testable import Lexical

final class TabBarFigmaSpecTests: XCTestCase {
    func testBottomNavGeometryUsesSystemLikeSizing() {
        let spec = TabBarFigmaSpec()

        XCTAssertEqual(spec.contentHeight, 49, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(spec.minimumHitTarget, 44)
        XCTAssertEqual(spec.topCornerRadius, 15, accuracy: 0.001)
        XCTAssertEqual(spec.iconSize, 22, accuracy: 0.001)
    }

    func testBottomNavStrokePaletteUsesAccessibleContrast() {
        let spec = TabBarFigmaSpec()

        XCTAssertEqual(spec.lightTopBorderHex, "D1D5DC")
        XCTAssertEqual(spec.darkTopBorderHex, "D1D5DC")
        XCTAssertEqual(spec.lightBackgroundHex, "FFFFFF")
        XCTAssertEqual(spec.darkBackgroundHex, "FFFFFF")
    }
}
