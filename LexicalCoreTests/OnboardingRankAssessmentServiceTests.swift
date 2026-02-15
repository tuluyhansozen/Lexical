import XCTest
@testable import LexicalCore

final class OnboardingRankAssessmentServiceTests: XCTestCase {
    func testBuildQuestionsReturnsTenQuestionsWithTwoDistractors() {
        let service = OnboardingRankAssessmentService()
        let lexemes = makeLexemes()

        let questions = service.buildQuestions(from: lexemes, questionCount: 10)

        XCTAssertEqual(questions.count, 10)
        XCTAssertEqual(questions.filter(\.isDistractor).count, 2)
        XCTAssertEqual(questions.filter { !$0.isDistractor }.count, 8)
        XCTAssertEqual(Set(questions.map(\.id)).count, 10)
    }

    func testEvaluateProducesHigherRankForStrongerAnswers() throws {
        let service = OnboardingRankAssessmentService()
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 10)

        var strongAnswers: [String: OnboardingCalibrationAnswer] = [:]
        var weakAnswers: [String: OnboardingCalibrationAnswer] = [:]

        for question in questions {
            strongAnswers[question.id] = question.isDistractor ? .dontKnow : .know
            weakAnswers[question.id] = .dontKnow
        }

        let strongResult = try XCTUnwrap(
            service.evaluate(questions: questions, answers: strongAnswers)
        )
        let weakResult = try XCTUnwrap(
            service.evaluate(questions: questions, answers: weakAnswers)
        )

        XCTAssertGreaterThan(strongResult.estimatedRank, weakResult.estimatedRank)
    }

    func testEvaluatePenalizesDistractorOverclaims() throws {
        let service = OnboardingRankAssessmentService()
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 10)

        var honestAnswers: [String: OnboardingCalibrationAnswer] = [:]
        var overclaimAnswers: [String: OnboardingCalibrationAnswer] = [:]

        for question in questions {
            honestAnswers[question.id] = question.isDistractor ? .dontKnow : .know
            overclaimAnswers[question.id] = .know
        }

        let honest = try XCTUnwrap(
            service.evaluate(questions: questions, answers: honestAnswers)
        )
        let overclaim = try XCTUnwrap(
            service.evaluate(questions: questions, answers: overclaimAnswers)
        )

        XCTAssertLessThan(overclaim.estimatedRank, honest.estimatedRank)
        XCTAssertGreaterThan(overclaim.distractorOverclaimRate, honest.distractorOverclaimRate)
    }

    private func makeLexemes() -> [LexemeDefinition] {
        [
            LexemeDefinition(lemma: "maintain", rank: 980, basicMeaning: "keep at current level"),
            LexemeDefinition(lemma: "resource", rank: 1_160, basicMeaning: "useful source"),
            LexemeDefinition(lemma: "resilient", rank: 2_420, basicMeaning: "able to recover quickly"),
            LexemeDefinition(lemma: "coherent", rank: 2_660, basicMeaning: "clear and logical"),
            LexemeDefinition(lemma: "nuance", rank: 4_420, basicMeaning: "subtle difference"),
            LexemeDefinition(lemma: "meticulous", rank: 4_680, basicMeaning: "very careful"),
            LexemeDefinition(lemma: "ubiquitous", rank: 6_960, basicMeaning: "found everywhere"),
            LexemeDefinition(lemma: "detrimental", rank: 7_180, basicMeaning: "harmful"),
            LexemeDefinition(lemma: "pragmatic", rank: 9_720, basicMeaning: "practical"),
            LexemeDefinition(lemma: "synthesize", rank: 10_240, basicMeaning: "combine ideas")
        ]
    }
}
