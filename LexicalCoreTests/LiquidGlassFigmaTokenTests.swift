import XCTest
@testable import LexicalCore

final class LiquidGlassFigmaTokenTests: XCTestCase {
    func testRootFigmaTokensMatchDesignValues() {
        XCTAssertEqual(LiquidGlassFigmaTokens.rootBackdropBlur, 12, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassFigmaTokens.rootBaseHex, "7B0002")
        XCTAssertEqual(LiquidGlassFigmaTokens.rootBurnOpacity, 0.57, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.rootGradientStartLocation, 0.5, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.rootGradientEndOpacity, 0.4, accuracy: 0.0001)
    }

    func testLeafFigmaTokensMatchDesignValues() {
        XCTAssertEqual(LiquidGlassFigmaTokens.leafColorBurnRed, 2.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafColorBurnGreen, 17.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafColorBurnBlue, 5.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafColorBurnOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafBackdropBlur, 12, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafGradientStartLocation, 0.50962, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafGradientEndOpacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(LiquidGlassFigmaTokens.leafBorderWidth, 2, accuracy: 0.001)
    }
}
