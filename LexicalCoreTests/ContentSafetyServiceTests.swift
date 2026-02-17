import XCTest
@testable import LexicalCore

final class ContentSafetyServiceTests: XCTestCase {
    func testIsSafeTextRejectsExpandedUnsafePatterns() {
        XCTAssertFalse(ContentSafetyService.isSafeText("This phrase says fuck clearly."))
        XCTAssertFalse(ContentSafetyService.isSafeText("The sentence mentions a terrorist."))
        XCTAssertFalse(ContentSafetyService.isSafeText("The text includes suicide directly."))
        XCTAssertFalse(ContentSafetyService.isSafeText("Use rape in this sentence."))
    }

    func testSanitizeTermsDropsUnsafeAndDeduplicates() {
        let input = ["clear", "CLEAR", "fuck", "terrorist", "practical"]
        let sanitized = ContentSafetyService.sanitizeTerms(input, maxCount: 8)

        XCTAssertEqual(sanitized, ["clear", "practical"])
    }

    func testSanitizeSentencesDropsUnsafeAndKeepsSafeOrder() {
        let input = [
            "This is a safe sentence for learning.",
            "He used fuck in that sentence.",
            "Another safe sentence with context."
        ]

        let sanitized = ContentSafetyService.sanitizeSentences(input, maxCount: 3)

        XCTAssertEqual(
            sanitized,
            [
                "This is a safe sentence for learning.",
                "Another safe sentence with context."
            ]
        )
    }
}
