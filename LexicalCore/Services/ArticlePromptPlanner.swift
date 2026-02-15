import Foundation

public struct ArticlePromptPlan: Sendable {
    public let category: String
    public let topic: String
    public let angleName: String
    public let angleDirective: String
    public let openingHook: String
    public let recentTitleExclusions: [String]
    public let recentTopicExclusions: [String]

    public init(
        category: String,
        topic: String,
        angleName: String,
        angleDirective: String,
        openingHook: String,
        recentTitleExclusions: [String],
        recentTopicExclusions: [String]
    ) {
        self.category = category
        self.topic = topic
        self.angleName = angleName
        self.angleDirective = angleDirective
        self.openingHook = openingHook
        self.recentTitleExclusions = recentTitleExclusions
        self.recentTopicExclusions = recentTopicExclusions
    }
}

public struct ArticlePromptMemoryStore {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let maxEntries: Int

    public init(
        defaults: UserDefaults? = nil,
        keyPrefix: String = "lexical.article.prompt_memory.v1",
        maxEntries: Int = 40
    ) {
        if let defaults {
            self.defaults = defaults
        } else {
            self.defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        }
        self.keyPrefix = keyPrefix
        self.maxEntries = max(10, maxEntries)
    }

    fileprivate func recentEntries(for userId: String?) -> [ArticlePromptMemoryEntry] {
        let key = namespacedKey(for: userId)
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoded = (try? JSONDecoder().decode([ArticlePromptMemoryEntry].self, from: data)) ?? []
        return decoded
            .sorted { $0.generatedAt < $1.generatedAt }
            .suffix(maxEntries)
            .map { $0 }
    }

    fileprivate func append(
        category: String,
        topic: String,
        angleName: String,
        generatedAt: Date,
        userId: String?
    ) {
        var entries = recentEntries(for: userId)
        entries.append(
            ArticlePromptMemoryEntry(
                category: category,
                topic: topic,
                angleName: angleName,
                generatedAt: generatedAt
            )
        )
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: namespacedKey(for: userId))
    }

    private func namespacedKey(for userId: String?) -> String {
        let safeUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = safeUserId?.isEmpty == false ? safeUserId! : "global"
        return "\(keyPrefix).\(suffix)"
    }
}

public struct ArticlePromptPlanner {
    private let memoryStore: ArticlePromptMemoryStore
    private let nowProvider: () -> Date

    public init(
        memoryStore: ArticlePromptMemoryStore = .init(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.memoryStore = memoryStore
        self.nowProvider = nowProvider
    }

    public func buildPlan(
        profile: InterestProfile,
        recentArticles: [GeneratedArticle],
        targetWords: [String],
        userId: String?
    ) -> ArticlePromptPlan {
        let memoryEntries = memoryStore.recentEntries(for: userId)
        let category = selectCategory(
            profile: profile,
            recentArticles: recentArticles,
            memoryEntries: memoryEntries
        )
        let topics = topicCandidates(for: category)
        let topic = selectTopic(
            category: category,
            candidates: topics,
            recentArticles: recentArticles,
            memoryEntries: memoryEntries,
            targetWords: targetWords
        )
        let angle = selectAngle(
            recentArticles: recentArticles,
            memoryEntries: memoryEntries
        )

        return ArticlePromptPlan(
            category: category,
            topic: topic,
            angleName: angle.name,
            angleDirective: angle.directive,
            openingHook: buildOpeningHook(topic: topic, angleName: angle.name),
            recentTitleExclusions: dedupPreservingOrder(
                recentArticles.prefix(5).map(\.title).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ).filter { !$0.isEmpty },
            recentTopicExclusions: dedupPreservingOrder(
                memoryEntries.suffix(6).map(\.topic)
            )
        )
    }

    public func recordUsage(plan: ArticlePromptPlan, userId: String?) {
        memoryStore.append(
            category: plan.category,
            topic: plan.topic,
            angleName: plan.angleName,
            generatedAt: nowProvider(),
            userId: userId
        )
    }

    private func selectCategory(
        profile: InterestProfile,
        recentArticles: [GeneratedArticle],
        memoryEntries: [ArticlePromptMemoryEntry]
    ) -> String {
        let candidateCategories = categoryCandidates(from: profile)
        let recentCategories = recentArticles.prefix(8).map { normalizedCategory($0.category) }
        let recentMemoryCategories = memoryEntries.suffix(8).map { normalizedCategory($0.category) }

        var best: (category: String, score: Double)?
        for category in candidateCategories {
            let weight = max(0.1, profile.categoryWeights[category] ?? 1.0)
            let feedRepeatPenalty = Double(recentCategories.filter { $0 == category }.count) * 0.30
            let memoryRepeatPenalty = Double(recentMemoryCategories.filter { $0 == category }.count) * 0.35
            let score = weight - feedRepeatPenalty - memoryRepeatPenalty
            if best == nil || score > best!.score || (score == best!.score && category < best!.category) {
                best = (category, score)
            }
        }

        return best?.category ?? "Technology"
    }

    private func categoryCandidates(from profile: InterestProfile) -> [String] {
        let selected = profile.selectedTags
            .map(normalizedCategory)
            .filter { !$0.isEmpty }
        if !selected.isEmpty {
            return dedupPreservingOrder(selected)
        }

        let weighted = profile.categoryWeights.keys
            .map(normalizedCategory)
            .filter { !$0.isEmpty }
        if !weighted.isEmpty {
            return dedupPreservingOrder(weighted)
        }

        return ["Technology", "Science", "Productivity", "Business"]
    }

    private func selectTopic(
        category: String,
        candidates: [String],
        recentArticles: [GeneratedArticle],
        memoryEntries: [ArticlePromptMemoryEntry],
        targetWords: [String]
    ) -> String {
        let recentTextCorpus = recentArticles.prefix(12).map { "\($0.title) \($0.content.prefix(180))" }
        let recentTopics = memoryEntries.suffix(12).map(\.topic)
        let targetSet = Set(targetWords.map { $0.lowercased() })

        var best: (topic: String, score: Double)?
        for topic in candidates {
            let normalizedTopic = topic.lowercased()
            let feedNoveltyPenalty = maxSimilarity(of: normalizedTopic, against: recentTextCorpus) * 1.20
            let topicRepeatPenalty = recentTopics.contains(where: { $0.caseInsensitiveCompare(topic) == .orderedSame }) ? 0.85 : 0
            let targetFitBonus = targetSet.isEmpty ? 0 : targetFitBonus(topic: normalizedTopic, targetWords: targetSet)
            let score = 1.0 + targetFitBonus - feedNoveltyPenalty - topicRepeatPenalty

            if best == nil || score > best!.score || (score == best!.score && topic < best!.topic) {
                best = (topic, score)
            }
        }

        return best?.topic ?? defaultTopics(for: category).first ?? "\(category) systems thinking"
    }

    private func selectAngle(
        recentArticles: [GeneratedArticle],
        memoryEntries: [ArticlePromptMemoryEntry]
    ) -> AngleBlueprint {
        let recentAngles = memoryEntries.suffix(10).map(\.angleName)
        let recentTitleBody = recentArticles.prefix(8).map { "\($0.title) \($0.content.prefix(120))".lowercased() }

        var best: (angle: AngleBlueprint, score: Double)?
        for angle in Self.angleBlueprints {
            let usagePenalty = Double(recentAngles.filter { $0 == angle.name }.count) * 0.55
            let keywordPenalty = recentTitleBody.contains { text in
                angle.keywordHints.contains { text.contains($0) }
            } ? 0.20 : 0.0
            let score = 1.0 - usagePenalty - keywordPenalty
            if best == nil || score > best!.score || (score == best!.score && angle.name < best!.angle.name) {
                best = (angle, score)
            }
        }
        return best?.angle ?? Self.angleBlueprints[0]
    }

    private func targetFitBonus(topic: String, targetWords: Set<String>) -> Double {
        let topicTokens = Set(tokenize(topic))
        guard !topicTokens.isEmpty else { return 0 }
        let shared = topicTokens.intersection(targetWords).count
        if shared == 0 { return 0 }
        return min(0.30, Double(shared) * 0.12)
    }

    private func maxSimilarity(of text: String, against corpus: [String]) -> Double {
        let sourceTokens = Set(tokenize(text))
        guard !sourceTokens.isEmpty else { return 0 }

        var best = 0.0
        for item in corpus {
            let targetTokens = Set(tokenize(item))
            guard !targetTokens.isEmpty else { continue }
            let intersection = sourceTokens.intersection(targetTokens).count
            let union = sourceTokens.union(targetTokens).count
            guard union > 0 else { continue }
            let score = Double(intersection) / Double(union)
            if score > best {
                best = score
            }
        }
        return best
    }

    private func tokenize(_ raw: String) -> [String] {
        raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !Self.stopWords.contains($0) }
    }

    private func buildOpeningHook(topic: String, angleName: String) -> String {
        switch angleName {
        case "Trade-off Breakdown":
            return "What practical benefit does \(topic.lowercased()) offer, and what does it cost in time, focus, or complexity?"
        case "Case Study Walkthrough":
            return "Follow one realistic learner scenario that succeeds or fails based on how \(topic.lowercased()) is applied."
        case "Myth vs Reality":
            return "Which common belief about \(topic.lowercased()) sounds plausible but breaks in real usage?"
        case "Decision Framework":
            return "What 3-step decision framework can readers use this week when facing \(topic.lowercased()) choices?"
        case "Failure Postmortem":
            return "Start with a realistic mistake and explain how to recover using better \(topic.lowercased()) habits."
        default:
            return "Open with one concrete problem that makes \(topic.lowercased()) immediately relevant to an intermediate learner."
        }
    }

    private func topicCandidates(for category: String) -> [String] {
        let normalized = normalizedCategory(category)
        if let configured = Self.topicBank[normalized], !configured.isEmpty {
            return configured
        }
        return defaultTopics(for: normalized)
    }

    private func defaultTopics(for category: String) -> [String] {
        let normalized = normalizedCategory(category).lowercased()
        return [
            "\(normalized) decision-making under constraints",
            "common mistakes in \(normalized) and practical fixes",
            "\(normalized) habits that compound over 30 days",
            "trade-offs beginners miss in \(normalized)",
            "how to evaluate claims in \(normalized) without hype",
            "\(normalized) systems that fail and why"
        ]
    }

    private func normalizedCategory(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "General" }
        let lower = trimmed.lowercased()
        let aliases: [String: String] = [
            "tech": "Technology",
            "technology": "Technology",
            "programming": "Technology",
            "data science": "Technology",
            "artificial intelligence": "Technology",
            "cybersecurity": "Technology",
            "sci": "Science",
            "science": "Science",
            "space": "Science",
            "mathematics": "Science",
            "biotech": "Science",
            "productivity": "Productivity",
            "education": "Productivity",
            "language learning": "Productivity",
            "personal growth": "Productivity",
            "remote work": "Productivity",
            "business": "Business",
            "startups": "Business",
            "marketing": "Business",
            "leadership": "Business",
            "negotiation": "Business",
            "culture": "Culture",
            "art": "Culture",
            "cinema": "Culture",
            "music": "Culture",
            "design": "Culture",
            "architecture": "Culture",
            "literature": "Culture",
            "fashion": "Culture",
            "theater": "Culture",
            "podcasts": "Culture",
            "tv series": "Culture",
            "history": "History",
            "politics": "History",
            "law": "History",
            "global affairs": "History",
            "current events": "History",
            "nature": "Nature",
            "climate": "Nature",
            "geography": "Nature",
            "wildlife": "Nature",
            "botany": "Nature",
            "marine life": "Nature",
            "travel": "Nature",
            "camping": "Nature",
            "backpacking": "Nature",
            "health": "Health",
            "health care": "Health",
            "medicine": "Health",
            "fitness": "Health",
            "nutrition": "Health",
            "sports": "Health",
            "running": "Health",
            "cycling": "Health",
            "climbing": "Health",
            "swimming": "Health",
            "yoga": "Health",
            "psychology": "Psychology",
            "mental health": "Psychology",
            "finance": "Finance",
            "economics": "Finance",
            "investing": "Finance",
            "personal finance": "Finance",
            "crypto": "Finance",
            "real estate": "Finance"
        ]
        return aliases[lower] ?? trimmed.capitalized
    }

    private func dedupPreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(normalized)
        }
        return result
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "your",
        "about", "over", "under", "after", "before", "when", "where", "what",
        "why", "how", "are", "was", "were", "their", "them", "they", "you"
    ]

    private static let angleBlueprints: [AngleBlueprint] = [
        AngleBlueprint(
            name: "Trade-off Breakdown",
            directive: "Compare two viable approaches, make one explicit trade-off, and explain when each option fails.",
            keywordHints: ["trade-off", "compare", "constraint"]
        ),
        AngleBlueprint(
            name: "Case Study Walkthrough",
            directive: "Anchor the article in one realistic scenario and revisit it across sections to show evolving decisions.",
            keywordHints: ["case", "scenario", "walkthrough"]
        ),
        AngleBlueprint(
            name: "Myth vs Reality",
            directive: "Start from a common misconception, then correct it with concrete examples and boundary conditions.",
            keywordHints: ["myth", "reality", "misconception"]
        ),
        AngleBlueprint(
            name: "Decision Framework",
            directive: "Teach a practical 3-step decision framework and show how each step applies to a concrete situation.",
            keywordHints: ["framework", "decision", "checklist"]
        ),
        AngleBlueprint(
            name: "Failure Postmortem",
            directive: "Begin with a realistic failure pattern, diagnose root causes, and end with a prevention playbook.",
            keywordHints: ["failure", "postmortem", "diagnose"]
        )
    ]

    private static let topicBank: [String: [String]] = [
        "Technology": [
            "human-in-the-loop AI for language learning",
            "notification fatigue and attention recovery",
            "privacy-by-design for educational apps",
            "edge inference vs cloud inference trade-offs",
            "building reliable habits with low-friction automation",
            "why simple tools outperform feature-heavy systems",
            "designing trustworthy recommendation systems",
            "latency budgets and perceived app quality",
            "offline-first architectures for mobile learning",
            "how product analytics can mislead decisions"
        ],
        "Science": [
            "how memory consolidation changes overnight learning",
            "attention as a limited biological resource",
            "desirable difficulty and long-term retention",
            "why retrieval practice beats passive review",
            "the cost of cognitive overload in daily routines",
            "how stress affects language recall under pressure",
            "small experiments for behavior change",
            "signal vs noise in scientific headlines",
            "the role of sleep in vocabulary acquisition",
            "using uncertainty as a learning tool"
        ],
        "Productivity": [
            "designing a sustainable daily reading loop",
            "how to reduce context switching in study sessions",
            "weekly planning for consistent language growth",
            "high-leverage routines for busy learners",
            "timeboxing vs task batching in deep work",
            "building review habits that survive low-motivation days",
            "practical prioritization under limited time",
            "avoiding optimization theater in personal workflows",
            "feedback loops that actually improve output",
            "execution systems that prevent burnout"
        ],
        "Business": [
            "decision quality vs decision speed in teams",
            "how incentives shape learning culture",
            "operational bottlenecks and compounding delays",
            "process discipline without bureaucracy",
            "why clear metrics still produce bad outcomes",
            "pricing trade-offs for digital products",
            "risk management in uncertain markets",
            "communication failures in cross-functional teams",
            "strategy execution under resource constraints",
            "long-term moat vs short-term growth pressure"
        ],
        "Culture": [
            "how media narratives shape public vocabulary",
            "attention economies and cultural memory",
            "cross-cultural communication in remote teams",
            "how trends become norms in digital communities",
            "reading bias in opinion-driven content",
            "storytelling patterns that influence belief",
            "how symbols carry meaning across contexts",
            "language, identity, and social belonging",
            "slow culture vs algorithmic acceleration",
            "why context changes interpretation"
        ],
        "Psychology": [
            "habit loops and cue design for consistency",
            "self-efficacy and learning persistence",
            "why motivation follows action",
            "cognitive distortions in self-assessment",
            "confidence calibration after mistakes",
            "emotion regulation during difficult study sessions",
            "attention drift and recovery strategies",
            "identity-based behavior change",
            "goal setting that avoids perfection traps",
            "how reflection improves recall"
        ],
        "Health": [
            "sleep quality and learning performance",
            "stress management for sustained focus",
            "movement breaks and mental clarity",
            "nutrition habits that support concentration",
            "digital hygiene and cognitive recovery",
            "burnout signals and early interventions",
            "building healthy study intensity",
            "screen-time boundaries that work",
            "rest as part of high performance",
            "consistency over intensity in health routines"
        ],
        "Finance": [
            "compound growth and long-term decisions",
            "risk tolerance under uncertainty",
            "how incentives distort financial judgment",
            "opportunity cost in daily choices",
            "decision frameworks for budget trade-offs",
            "behavioral traps in spending habits",
            "short-term volatility vs long-term strategy",
            "cash-flow habits for stability",
            "how narratives drive market behavior",
            "practical uncertainty management in planning"
        ],
        "History": [
            "how institutions evolve under pressure",
            "lessons from failed policy experiments",
            "technology adoption across historical eras",
            "trade networks and cultural diffusion",
            "decision errors that changed outcomes",
            "how communication systems shape power",
            "resource constraints in historical strategy",
            "why reforms succeed or stall",
            "the role of narrative in historical memory",
            "historical parallels for modern decisions"
        ],
        "Nature": [
            "ecosystem resilience under gradual stress",
            "feedback loops in environmental systems",
            "adaptation strategies in changing habitats",
            "biodiversity and system stability",
            "trade-offs in conservation policy",
            "human behavior and ecological outcomes",
            "long-term thinking in environmental planning",
            "resource limits and sustainable decisions",
            "signal detection in climate data narratives",
            "why local interventions scale poorly"
        ]
    ]
}

private struct AngleBlueprint {
    let name: String
    let directive: String
    let keywordHints: [String]
}

private struct ArticlePromptMemoryEntry: Codable {
    let category: String
    let topic: String
    let angleName: String
    let generatedAt: Date
}
