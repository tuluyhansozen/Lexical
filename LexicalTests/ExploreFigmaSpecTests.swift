import XCTest
@testable import Lexical

final class ExploreFigmaSpecTests: XCTestCase {
    func testTypographyMatchesFigmaValues() {
        let spec = ExploreVisualSpec()

        XCTAssertEqual(spec.titleFontSize, 32, accuracy: 0.001)
        XCTAssertEqual(spec.subtitleFontSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.rootPrimaryFontSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.rootSecondaryFontSize, 10, accuracy: 0.001)
        XCTAssertEqual(spec.leafFontSize, 9, accuracy: 0.001)
    }

    func testHeaderAndStyleConstantsMatchFigmaIntent() {
        let spec = ExploreVisualSpec()

        XCTAssertEqual(spec.titleText, "Explore")
        XCTAssertEqual(spec.subtitleText, "Daily word families for you")
        XCTAssertEqual(spec.lightBackgroundHex, "F5F5F7")
        XCTAssertEqual(spec.connectorLineWidth, 0.9, accuracy: 0.0001)
        XCTAssertEqual(spec.connectorHexLight, "D1D5DC")
        XCTAssertEqual(spec.leafFillHexLight, "50605A")
        XCTAssertEqual(spec.rootFillHexLight, "7B0002")
        XCTAssertEqual(spec.rootFillOpacity, 0.60, accuracy: 0.0001)
        XCTAssertEqual(spec.designCanvasSize.width, 392.99, accuracy: 0.001)
        XCTAssertEqual(spec.designCanvasSize.height, 624.02, accuracy: 0.001)
    }

    func testRootDefaultsMatchFigmaReference() {
        let spec = ExploreVisualSpec()

        XCTAssertEqual(spec.rootLabel, "spec")
        XCTAssertEqual(spec.rootMeaning, "A morphological root tied to seeing, looking, and observation.")
        assertPoint(spec.rootPosition, equals: CGPoint(x: 0.5181, y: 0.4666))
        XCTAssertEqual(spec.rootDiameter, 98.409, accuracy: 0.001)
    }

    func testLeafSlotsMatchFigmaReference() {
        let spec = ExploreVisualSpec()

        XCTAssertEqual(spec.leafSlots.count, 6)

        XCTAssertEqual(spec.leafSlots[0].label, "Spectator")
        assertPoint(spec.leafSlots[0].position, equals: CGPoint(x: 0.3472, y: 0.1948))
        XCTAssertEqual(spec.leafSlots[0].diameter, 73.192, accuracy: 0.001)

        XCTAssertEqual(spec.leafSlots[1].label, "Retrospect")
        assertPoint(spec.leafSlots[1].position, equals: CGPoint(x: 0.7009, y: 0.2239))
        XCTAssertEqual(spec.leafSlots[1].diameter, 87.811, accuracy: 0.001)

        XCTAssertEqual(spec.leafSlots[2].label, "Spectacle")
        assertPoint(spec.leafSlots[2].position, equals: CGPoint(x: 0.2152, y: 0.3590))
        XCTAssertEqual(spec.leafSlots[2].diameter, 73.192, accuracy: 0.001)

        XCTAssertEqual(spec.leafSlots[3].label, "Conspicuous")
        assertPoint(spec.leafSlots[3].position, equals: CGPoint(x: 0.7821, y: 0.5754))
        XCTAssertEqual(spec.leafSlots[3].diameter, 82.464, accuracy: 0.001)

        XCTAssertEqual(spec.leafSlots[4].label, "Perspective")
        assertPoint(spec.leafSlots[4].position, equals: CGPoint(x: 0.2525, y: 0.6404))
        XCTAssertEqual(spec.leafSlots[4].diameter, 89.105, accuracy: 0.001)

        XCTAssertEqual(spec.leafSlots[5].label, "Inspect")
        assertPoint(spec.leafSlots[5].position, equals: CGPoint(x: 0.5097, y: 0.7363))
        XCTAssertEqual(spec.leafSlots[5].diameter, 73.139, accuracy: 0.001)
    }

    private func assertPoint(_ lhs: CGPoint, equals rhs: CGPoint, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: 0.0001, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: 0.0001, line: line)
    }
}
