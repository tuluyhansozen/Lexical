import XCTest
@testable import Lexical

final class ExploreFigmaSpecTests: XCTestCase {
    func testHeaderAndStyleConstantsMatchFigmaIntent() {
        let spec = ExploreFigmaSpec()

        XCTAssertEqual(spec.titleText, "Explore")
        XCTAssertEqual(spec.subtitleText, "Daily word families for you")
        XCTAssertEqual(spec.lightBackgroundHex, "F5F5F7")
        XCTAssertEqual(spec.connectorLineWidth, 1, accuracy: 0.0001)
        XCTAssertEqual(spec.rootNodeStyleKey, "rootCoralGlass")
        XCTAssertEqual(spec.leafNodeStyleKey, "leafGreenGlass")
    }

    func testRootDefaultsMatchFigmaReference() {
        let spec = ExploreFigmaSpec()

        XCTAssertEqual(spec.rootLabel, "spec")
        XCTAssertEqual(spec.rootMeaning, "A morphological root tied to seeing, looking, and observation.")
        assertPoint(spec.rootPosition, equals: CGPoint(x: 0.50, y: 0.4432))
        XCTAssertEqual(spec.rootDiameter, 99, accuracy: 0.001)
    }

    func testLeafSlotsMatchFigmaReference() {
        let spec = ExploreFigmaSpec()

        XCTAssertEqual(spec.leaves.count, 6)

        XCTAssertEqual(spec.leaves[0].label, "Spectator")
        assertPoint(spec.leaves[0].position, equals: CGPoint(x: 0.3143, y: 0.1473))
        XCTAssertEqual(spec.leaves[0].diameter, 73, accuracy: 0.001)

        XCTAssertEqual(spec.leaves[1].label, "Retrospect")
        assertPoint(spec.leaves[1].position, equals: CGPoint(x: 0.6985, y: 0.1787))
        XCTAssertEqual(spec.leaves[1].diameter, 88, accuracy: 0.001)

        XCTAssertEqual(spec.leaves[2].label, "Spectacle")
        assertPoint(spec.leaves[2].position, equals: CGPoint(x: 0.1710, y: 0.3260))
        XCTAssertEqual(spec.leaves[2].diameter, 73, accuracy: 0.001)

        XCTAssertEqual(spec.leaves[3].label, "Conspicious")
        assertPoint(spec.leaves[3].position, equals: CGPoint(x: 0.7868, y: 0.5615))
        XCTAssertEqual(spec.leaves[3].diameter, 82, accuracy: 0.001)

        XCTAssertEqual(spec.leaves[4].label, "Perspective")
        assertPoint(spec.leaves[4].position, equals: CGPoint(x: 0.2114, y: 0.6323))
        XCTAssertEqual(spec.leaves[4].diameter, 89, accuracy: 0.001)

        XCTAssertEqual(spec.leaves[5].label, "Inspect")
        assertPoint(spec.leaves[5].position, equals: CGPoint(x: 0.4908, y: 0.7367))
        XCTAssertEqual(spec.leaves[5].diameter, 73, accuracy: 0.001)
    }

    private func assertPoint(_ lhs: CGPoint, equals rhs: CGPoint, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: 0.0001, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: 0.0001, line: line)
    }
}
