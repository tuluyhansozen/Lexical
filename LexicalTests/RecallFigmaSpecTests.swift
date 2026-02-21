import XCTest
@testable import Lexical

final class RecallFigmaSpecTests: XCTestCase {
    func testTypographyAndLayoutConstantsMatchFigmaBaseline() {
        let spec = RecallFigmaSpec()

        XCTAssertEqual(spec.screenTitle, "Recall Session")
        XCTAssertEqual(spec.screenSubtitle, "Daily active recall")
        XCTAssertEqual(spec.headerTitleFontSize, 24, accuracy: 0.001)
        XCTAssertEqual(spec.headerSubtitleFontSize, 16, accuracy: 0.001)
        XCTAssertEqual(spec.cardCornerRadius, 14, accuracy: 0.001)
        XCTAssertEqual(spec.gradeButtonSize.width, 60, accuracy: 0.001)
        XCTAssertEqual(spec.gradeButtonSize.height, 60, accuracy: 0.001)
        XCTAssertEqual(spec.gradeButtonCornerRadius, 20, accuracy: 0.001)
    }

    func testColorTokensMatchRecallPalette() {
        let spec = RecallFigmaSpec()

        XCTAssertEqual(spec.lightBackgroundHex, "F5F5F7")
        XCTAssertEqual(spec.darkBackgroundHex, "0A101A")
        XCTAssertEqual(spec.progressTrackHex, "BCBCBC")
        XCTAssertEqual(spec.progressFillHex, "144932")
        XCTAssertEqual(spec.neutralActionBackgroundHex, "E7E8EC")
        XCTAssertEqual(spec.neutralActionTextHex, "444B56")
        XCTAssertEqual(spec.gradeAgainHex, "E8B7B5")
        XCTAssertEqual(spec.gradeHardHex, "E6D2A5")
        XCTAssertEqual(spec.gradeGoodHex, "AFD7C5")
        XCTAssertEqual(spec.gradeEasyHex, "A4DBBA")
    }

    func testMotionDurationsAreStableForTransitions() {
        let spec = RecallFigmaSpec()

        XCTAssertEqual(spec.revealDuration, 0.16, accuracy: 0.0001)
        XCTAssertEqual(spec.advanceDuration, 0.22, accuracy: 0.0001)
    }
}
