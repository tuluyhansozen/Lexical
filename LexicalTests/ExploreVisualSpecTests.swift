import SwiftUI
import XCTest
@testable import Lexical

final class ExploreVisualSpecTests: XCTestCase {
    func testLabelPolicyKeepsFullLabelAtRegularTypeSizes() {
        XCTAssertEqual(
            ExploreNodeLabelPolicy.renderedLabel(
                for: "retrospective",
                dynamicTypeSize: DynamicTypeSize.large
            ),
            "Retrospective"
        )
    }

    func testLabelPolicyAbbreviatesAtAccessibilitySizes() {
        XCTAssertEqual(
            ExploreNodeLabelPolicy.renderedLabel(
                for: "retrospective",
                dynamicTypeSize: DynamicTypeSize.accessibility3
            ),
            "Retrosp…"
        )
    }

    func testAccessibilityLabelAlwaysUsesFullWord() {
        XCTAssertEqual(
            ExploreNodeLabelPolicy.accessibilityLabel(for: "retrospective"),
            "Retrospective"
        )
    }

    func testAccessibilityModeFallsBackToListForReduceMotion() {
        XCTAssertEqual(
            ExploreAccessibilityMode.resolve(
                reduceMotion: true,
                dynamicTypeSize: DynamicTypeSize.large
            ),
            ExploreAccessibilityMode.list
        )
    }

    func testAccessibilityModeFallsBackToListForAccessibilityTypeSizes() {
        XCTAssertEqual(
            ExploreAccessibilityMode.resolve(
                reduceMotion: false,
                dynamicTypeSize: DynamicTypeSize.accessibility2
            ),
            ExploreAccessibilityMode.list
        )
    }

    func testAccessibilityModeKeepsGraphForStandardType() {
        XCTAssertEqual(
            ExploreAccessibilityMode.resolve(
                reduceMotion: false,
                dynamicTypeSize: DynamicTypeSize.large
            ),
            ExploreAccessibilityMode.graph
        )
    }
}
