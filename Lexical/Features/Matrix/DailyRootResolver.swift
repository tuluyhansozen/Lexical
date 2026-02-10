import Foundation
import LexicalCore

/// Resolves deterministic daily root + adaptive satellite selections for Explore matrix rendering.
@MainActor
struct DailyRootResolver {
    struct Satellite {
        let lemma: String
        let status: UserWordStatus?
        let isFallback: Bool
    }

    struct Resolution {
        let centerLemma: String
        let rootLabel: String
        let rootMeaning: String
        let satellites: [Satellite]
    }

    private let calibrationEngine: LexicalCalibrationEngine

    init(calibrationEngine: LexicalCalibrationEngine = .init()) {
        self.calibrationEngine = calibrationEngine
    }

    func resolve(
        roots: [MorphologicalRoot],
        lexemes: [LexemeDefinition],
        userStates: [UserWordState],
        profile: UserProfile,
        highlightedLemma: String?,
        date: Date = Date()
    ) -> Resolution? {
        let sortedRoots = roots.sorted { $0.rootId < $1.rootId }
        guard !sortedRoots.isEmpty else { return nil }

        let ignored = Set(profile.ignoredWords.map { $0.lowercased() })
        let proximalRange = calibrationEngine.proximalRange(for: profile.lexicalRank)

        var lexemeBySeedID: [Int: LexemeDefinition] = [:]
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeBySeedID.reserveCapacity(lexemes.count)
        lexemeByLemma.reserveCapacity(lexemes.count)

        for lexeme in lexemes {
            if let seedID = lexeme.seedId {
                lexemeBySeedID[seedID] = lexeme
            }
            lexemeByLemma[lexeme.lemma] = lexeme
        }

        let dayID = Int(floor(date.timeIntervalSince1970 / 86_400))
        let rootIndex = ((dayID % sortedRoots.count) + sortedRoots.count) % sortedRoots.count

        let normalizedHighlight = highlightedLemma?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let selectedRoot: MorphologicalRoot = {
            guard let normalizedHighlight,
                  let highlightLexeme = lexemeByLemma[normalizedHighlight],
                  let seedID = highlightLexeme.seedId else {
                return sortedRoots[rootIndex]
            }
            return sortedRoots.first(where: { $0.wordIds.contains(seedID) }) ?? sortedRoots[rootIndex]
        }()

        let centerLemma = normalizedHighlight ?? selectedRoot.root.lowercased()

        let activeStates = userStates.filter { $0.userId == profile.userId }
        var statusByLemma: [String: UserWordStatus] = [:]
        statusByLemma.reserveCapacity(activeStates.count)
        for state in activeStates {
            statusByLemma[state.lemma] = state.status
        }

        let directCandidates = selectedRoot.wordIds
            .compactMap { lexemeBySeedID[$0] }
            .filter { lexeme in
                lexeme.lemma != centerLemma && !ignored.contains(lexeme.lemma)
            }

        func score(_ lexeme: LexemeDefinition) -> (inRange: Bool, distance: Int, lemma: String) {
            let rank = lexeme.rank ?? profile.lexicalRank
            return (
                proximalRange.contains(rank),
                abs(rank - profile.lexicalRank),
                lexeme.lemma
            )
        }

        let sortedDirect = directCandidates.sorted { lhs, rhs in
            let lhsScore = score(lhs)
            let rhsScore = score(rhs)
            if lhsScore.inRange != rhsScore.inRange { return lhsScore.inRange && !rhsScore.inRange }
            if lhsScore.distance != rhsScore.distance { return lhsScore.distance < rhsScore.distance }
            return lhsScore.lemma < rhsScore.lemma
        }

        var satellites: [Satellite] = sortedDirect.prefix(6).map { lexeme in
            Satellite(
                lemma: lexeme.lemma,
                status: statusByLemma[lexeme.lemma],
                isFallback: false
            )
        }

        var selectedLemmas = Set(satellites.map(\.lemma))
        selectedLemmas.insert(centerLemma)

        if satellites.count < 6 {
            let needed = 6 - satellites.count
            let fallbackCandidates = lexemes
                .filter { lexeme in
                    !selectedLemmas.contains(lexeme.lemma) &&
                    !ignored.contains(lexeme.lemma)
                }
                .sorted { lhs, rhs in
                    let lhsScore = score(lhs)
                    let rhsScore = score(rhs)
                    if lhsScore.inRange != rhsScore.inRange { return lhsScore.inRange && !rhsScore.inRange }
                    if lhsScore.distance != rhsScore.distance { return lhsScore.distance < rhsScore.distance }
                    return lhsScore.lemma < rhsScore.lemma
                }
                .prefix(needed)

            for lexeme in fallbackCandidates {
                satellites.append(
                    Satellite(
                        lemma: lexeme.lemma,
                        status: statusByLemma[lexeme.lemma],
                        isFallback: true
                    )
                )
            }
        }

        return Resolution(
            centerLemma: centerLemma,
            rootLabel: selectedRoot.root.uppercased(),
            rootMeaning: selectedRoot.basicMeaning,
            satellites: Array(satellites.prefix(6))
        )
    }
}
