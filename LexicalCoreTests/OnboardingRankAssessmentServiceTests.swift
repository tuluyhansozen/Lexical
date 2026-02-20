import XCTest
@testable import LexicalCore

final class OnboardingRankAssessmentServiceTests: XCTestCase {
    func testBuildQuestionsReturnsConfiguredPacketForTwelveQuestionOnboarding() {
        let service = OnboardingRankAssessmentService()
        let lexemes = makeLexemes()

        let questions = service.buildQuestions(from: lexemes, questionCount: 12)

        XCTAssertEqual(questions.count, 12)
        XCTAssertEqual(questions.filter(\.isDistractor).count, 2)
        XCTAssertEqual(Set(questions.map(\.id)).count, 12)
        XCTAssertEqual(
            questions.map(\.lemma),
            [
                "predict",
                "suggest",
                "consequence",
                "efficient",
                "constraint",
                "nuance",
                "meticulous",
                "ubiquitous",
                "cogent",
                "egregious",
                "sornity",
                "dravicle"
            ]
        )
        XCTAssertEqual(
            questions.map(\.isDistractor),
            [false, false, false, false, false, false, false, false, false, false, true, true]
        )
    }

    func testEvaluateProducesHigherRankForStrongerAnswers() throws {
        let service = OnboardingRankAssessmentService()
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 12)

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
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 12)

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

    func testEvaluateTreatsUnsureAsPartialKnowledge() throws {
        let service = OnboardingRankAssessmentService()
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 12)

        var unsureAnswers: [String: OnboardingCalibrationAnswer] = [:]
        var dontKnowAnswers: [String: OnboardingCalibrationAnswer] = [:]

        for question in questions {
            unsureAnswers[question.id] = question.isDistractor ? .dontKnow : .unsure
            dontKnowAnswers[question.id] = .dontKnow
        }

        let unsureResult = try XCTUnwrap(
            service.evaluate(questions: questions, answers: unsureAnswers)
        )
        let dontKnowResult = try XCTUnwrap(
            service.evaluate(questions: questions, answers: dontKnowAnswers)
        )

        XCTAssertGreaterThan(unsureResult.estimatedRank, dontKnowResult.estimatedRank)
    }

    func testEvaluateAppliesPriorRankAsWarmStart() throws {
        let service = OnboardingRankAssessmentService()
        let questions = service.buildQuestions(from: makeLexemes(), questionCount: 12)

        var mixedAnswers: [String: OnboardingCalibrationAnswer] = [:]
        var realIndex = 0
        for question in questions {
            guard !question.isDistractor else {
                mixedAnswers[question.id] = .dontKnow
                continue
            }

            mixedAnswers[question.id] = realIndex < 4 ? .know : .dontKnow
            realIndex += 1
        }

        let lowPrior = try XCTUnwrap(
            service.evaluate(
                questions: questions,
                answers: mixedAnswers,
                priorRank: 3_000
            )
        )
        let highPrior = try XCTUnwrap(
            service.evaluate(
                questions: questions,
                answers: mixedAnswers,
                priorRank: 15_000
            )
        )

        XCTAssertGreaterThan(highPrior.estimatedRank, lowPrior.estimatedRank)
    }

    private func makeLexemes() -> [LexemeDefinition] {
        [
            LexemeDefinition(lemma: "predict", rank: 8_692, basicMeaning: "say what will happen later"),
            LexemeDefinition(lemma: "suggest", rank: 2_199, basicMeaning: "offer an idea"),
            LexemeDefinition(lemma: "consequence", rank: 8_419, basicMeaning: "a result of an action"),
            LexemeDefinition(lemma: "efficient", rank: 3_315, basicMeaning: "working well with little waste"),
            LexemeDefinition(lemma: "constraint", rank: 9_968, basicMeaning: "a limitation"),
            LexemeDefinition(lemma: "nuance", rank: 15_400, basicMeaning: "a subtle difference"),
            LexemeDefinition(lemma: "meticulous", rank: 17_000, basicMeaning: "very careful and precise"),
            LexemeDefinition(lemma: "ubiquitous", rank: 19_403, basicMeaning: "present everywhere")
        ]
    }
}
