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
    private let noveltyScorer: ArticleNoveltyScorer
    private let nowProvider: () -> Date

    public init(
        memoryStore: ArticlePromptMemoryStore = .init(),
        noveltyScorer: ArticleNoveltyScorer = .init(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.memoryStore = memoryStore
        self.noveltyScorer = noveltyScorer
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
        let topics = topicCandidates(for: category, profile: profile)
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
            let semanticPenalty = noveltyScorer.semanticSimilarity(of: topic, against: recentTextCorpus) * 1.15
            let lexicalPenalty = noveltyScorer.lexicalSimilarity(of: topic, against: recentTextCorpus) * 0.35
            let topicRepeatPenalty = recentTopics.contains(where: { $0.caseInsensitiveCompare(topic) == .orderedSame }) ? 0.85 : 0
            let targetFitBonus = targetSet.isEmpty ? 0 : targetFitBonus(topic: normalizedTopic, targetWords: targetSet)
            let score = 1.0 + targetFitBonus - semanticPenalty - lexicalPenalty - topicRepeatPenalty

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

    private func topicCandidates(for category: String, profile: InterestProfile) -> [String] {
        let normalized = normalizedCategory(category)
        var candidates: [String] = []

        if let configured = Self.topicBank[normalized] {
            candidates.append(contentsOf: configured)
        }
        candidates.append(contentsOf: nicheTopicCandidates(for: normalized, profile: profile))

        let deduped = dedupPreservingOrder(candidates)
        if !deduped.isEmpty {
            return deduped
        }
        return defaultTopics(for: normalized)
    }

    private func nicheTopicCandidates(for category: String, profile: InterestProfile) -> [String] {
        let normalizedCategoryValue = normalizedCategory(category)
        let selectedTags = profile.selectedTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let matchingTags = selectedTags.filter {
            normalizedCategory($0) == normalizedCategoryValue ||
            normalizedCategory($0).caseInsensitiveCompare(category) == .orderedSame
        }

        var topics: [String] = []
        for tag in matchingTags {
            let key = tag.lowercased()
            if let mapped = Self.nicheTopicBank[key], !mapped.isEmpty {
                topics.append(contentsOf: mapped)
            } else {
                topics.append(contentsOf: synthesizedNicheTopics(for: tag))
            }
        }

        // If selected tags did not match (e.g., fallback category), still try direct category mapping.
        if topics.isEmpty {
            let categoryKey = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let mapped = Self.nicheTopicBank[categoryKey], !mapped.isEmpty {
                topics.append(contentsOf: mapped)
            }
        }

        return topics
    }

    private func synthesizedNicheTopics(for interest: String) -> [String] {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }
        return [
            "\(normalized) trends that will matter over the next year",
            "common misconceptions in \(normalized) and practical corrections",
            "a weekly practice framework for getting better at \(normalized)",
            "trade-offs learners miss when exploring \(normalized)"
        ]
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
            "cooking": "Productivity",
            "baking": "Productivity",
            "business": "Business",
            "startups": "Business",
            "marketing": "Business",
            "leadership": "Business",
            "negotiation": "Business",
            "culture": "Culture",
            "art": "Culture",
            "philosophy": "Culture",
            "cinema": "Culture",
            "music": "Culture",
            "gaming": "Culture",
            "podcasts": "Culture",
            "tv series": "Culture",
            "theater": "Culture",
            "design": "Culture",
            "architecture": "Culture",
            "illustration": "Culture",
            "crafts": "Culture",
            "literature": "Culture",
            "fashion": "Culture",
            "history": "History",
            "politics": "History",
            "law": "History",
            "global affairs": "History",
            "current events": "History",
            "social impact": "History",
            "volunteering": "History",
            "lgbtq+": "History",
            "nature": "Nature",
            "climate": "Nature",
            "geography": "Nature",
            "aviation": "Nature",
            "cars": "Nature",
            "motorcycles": "Nature",
            "wildlife": "Nature",
            "botany": "Nature",
            "marine life": "Nature",
            "travel": "Nature",
            "camping": "Nature",
            "backpacking": "Nature",
            "health": "Health",
            "health care": "Health",
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
            "investing": "Finance",
            "crypto": "Finance",
            "real estate": "Finance",
            "ufo": "Science",
            "mythology": "History"
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

    private static let nicheTopicBank: [String: [String]] = [
        "programming": [
            "debugging strategies that reduce repeated mistakes",
            "how to reason about code quality before refactoring",
            "trade-offs between rapid prototyping and maintainability"
        ],
        "data science": [
            "avoiding data leakage in practical model evaluation",
            "how framing a metric changes product decisions",
            "interpreting uncertainty without overconfidence"
        ],
        "artificial intelligence": [
            "where AI assistants fail in real workflows",
            "evaluation loops for reliable AI-assisted writing",
            "practical boundaries for human-in-the-loop automation"
        ],
        "cybersecurity": [
            "habit-based threat models for everyday users",
            "how social engineering bypasses technical controls",
            "incident postmortems that improve team behavior"
        ],
        "startups": [
            "finding product-market fit without vanity metrics",
            "when startup speed creates hidden quality debt",
            "founder decision patterns under uncertainty"
        ],
        "marketing": [
            "how message clarity beats channel volume",
            "diagnosing why campaigns convert but retention drops",
            "positioning trade-offs for crowded categories"
        ],
        "leadership": [
            "decision hygiene for managers under pressure",
            "how leaders create accountability without micromanagement",
            "communication rituals that reduce execution drift"
        ],
        "negotiation": [
            "anchoring effects and practical counter-techniques",
            "building win-win terms under asymmetric information",
            "common negotiation mistakes in everyday work"
        ],
        "investing": [
            "how narrative risk distorts investment choices",
            "portfolio decisions under regime uncertainty",
            "behavioral patterns behind panic selling"
        ],
        "crypto": [
            "separating protocol utility from speculation cycles",
            "risk controls for volatile digital asset exposure",
            "how custody and security choices shape outcomes"
        ],
        "real estate": [
            "cash-flow realism vs optimistic property projections",
            "location risk and long-horizon real estate decisions",
            "how financing structure changes total return"
        ],
        "philosophy": [
            "using first principles to improve daily decisions",
            "ethical trade-offs in modern technology design",
            "how philosophical framing shapes practical judgment"
        ],
        "literature": [
            "why narrative voice changes reader interpretation",
            "theme tracking techniques for deeper comprehension",
            "how literary structure improves long-form recall"
        ],
        "cinema": [
            "visual storytelling patterns that shape memory",
            "how editing pace changes perceived meaning",
            "genre expectations and audience interpretation"
        ],
        "music": [
            "how repetition and variation drive musical memory",
            "attention management during deep listening sessions",
            "interpreting production choices in modern tracks"
        ],
        "gaming": [
            "skill acquisition loops in competitive games",
            "how game feedback systems shape motivation",
            "design trade-offs between challenge and accessibility"
        ],
        "podcasts": [
            "active listening techniques for long-form audio",
            "how host format choices affect comprehension",
            "turning podcast insights into actionable notes"
        ],
        "tv series": [
            "episodic storytelling and long-arc retention",
            "how pacing shifts viewer interpretation",
            "theme continuity across multi-season narratives"
        ],
        "theater": [
            "how stage constraints sharpen storytelling decisions",
            "performance cues that guide audience attention",
            "adapting script interpretation across productions"
        ],
        "mental health": [
            "micro-habits that stabilize mood during heavy weeks",
            "cognitive reframing techniques that reduce rumination",
            "sustainable boundaries for digital mental load"
        ],
        "fitness": [
            "consistency systems that survive low-motivation days",
            "recovery trade-offs in high-frequency training plans",
            "how to measure progress beyond short-term intensity"
        ],
        "nutrition": [
            "decision frameworks for practical meal planning",
            "habit design for stable energy across workdays",
            "how food environments shape long-term behavior"
        ],
        "education": [
            "how retrieval-first study beats passive rereading",
            "feedback loop design for faster skill growth",
            "instructional trade-offs between depth and pace"
        ],
        "language learning": [
            "building fluency through retrieval and context reuse",
            "how to convert reading input into active output",
            "mistakes that slow intermediate language progress"
        ],
        "running": [
            "balancing volume and intensity for durable progress",
            "common pacing errors and practical corrections",
            "how training logs improve race-day decisions"
        ],
        "cycling": [
            "endurance progression without overtraining",
            "gear, cadence, and efficiency trade-offs",
            "planning recovery blocks for long-term cycling gains"
        ],
        "climbing": [
            "technique-first practice for climbing efficiency",
            "fear management in lead climbing decisions",
            "how route analysis improves attempt quality"
        ],
        "swimming": [
            "stroke efficiency habits for steady improvement",
            "interval design for mixed-skill swimmers",
            "breathing patterns and sustainable pace control"
        ],
        "yoga": [
            "mobility progress through consistent short sessions",
            "breath-led focus strategies for stressful weeks",
            "balancing flexibility goals with joint safety"
        ],
        "climate": [
            "how climate narratives affect public decisions",
            "adaptation vs mitigation trade-offs in policy choices",
            "interpreting uncertainty in climate communication"
        ],
        "geography": [
            "how geography shapes economic opportunity",
            "mapping literacy for better global understanding",
            "spatial reasoning habits for everyday decisions"
        ],
        "space": [
            "practical engineering constraints in modern space missions",
            "commercial space strategy beyond launch headlines",
            "how exploration goals shape technology priorities"
        ],
        "wildlife": [
            "habitat fragmentation and long-term species resilience",
            "field observation biases in wildlife reporting",
            "conservation trade-offs between policy options"
        ],
        "botany": [
            "plant adaptation strategies in changing environments",
            "how urban botany improves local ecosystems",
            "field methods for observing plant health signals"
        ],
        "travel": [
            "high-value travel planning under time constraints",
            "cultural learning frameworks for meaningful trips",
            "avoiding decision fatigue during multi-stop travel"
        ],
        "backpacking": [
            "pack-weight trade-offs for multi-day routes",
            "risk planning habits for remote backpacking trips",
            "navigation decisions when conditions change quickly"
        ],
        "camping": [
            "camp setup systems that reduce stress in bad weather",
            "safety-first routines for beginner campers",
            "gear selection trade-offs for short vs long trips"
        ],
        "aviation": [
            "crew resource management lessons for everyday teamwork",
            "how checklist discipline reduces high-stakes errors",
            "trade-offs between efficiency and safety margins in flight operations"
        ],
        "cars": [
            "maintenance habits that prevent expensive car failures",
            "how vehicle design trade-offs affect daily usability",
            "interpreting safety and efficiency claims in car marketing"
        ],
        "motorcycles": [
            "risk management routines for everyday riding",
            "how rider training changes hazard perception",
            "gear and visibility decisions that improve safety outcomes"
        ],
        "architecture": [
            "how spatial design influences behavior and focus",
            "trade-offs between aesthetics and long-term usability",
            "decision frameworks for human-centered architecture"
        ],
        "photography": [
            "compositional choices that improve storytelling",
            "practical lighting decisions in mixed environments",
            "editing discipline without losing authenticity"
        ],
        "fashion": [
            "style systems that reduce daily decision fatigue",
            "how materials and fit shape long-term quality",
            "trend adoption trade-offs for personal identity"
        ],
        "illustration": [
            "building visual consistency across illustration projects",
            "how constraints improve creative output quality",
            "feedback loops for faster artistic iteration"
        ],
        "crafts": [
            "deliberate practice routines for handmade skills",
            "material selection trade-offs in craft projects",
            "how repetition builds precision and creative range"
        ],
        "lgbtq+": [
            "how inclusive language evolves in public discourse",
            "community storytelling and identity formation",
            "media framing choices and social understanding"
        ],
        "law": [
            "how legal reasoning handles competing principles",
            "practical frameworks for reading policy changes",
            "why legal language precision changes outcomes"
        ],
        "social impact": [
            "measuring social impact beyond vanity metrics",
            "how grassroots initiatives scale without mission drift",
            "trade-offs between short-term aid and long-term resilience"
        ],
        "global affairs": [
            "how supply chains reshape geopolitical strategy",
            "decision-making under uncertainty in foreign policy",
            "reading global news without narrative bias traps"
        ],
        "volunteering": [
            "how volunteer programs sustain motivation over time",
            "matching local needs with practical contribution models",
            "operational habits that improve volunteer outcomes"
        ],
        "current events": [
            "fact-checking routines for fast-moving news cycles",
            "how framing effects distort public interpretation",
            "building balanced viewpoints from conflicting reports"
        ],
        "ufo": [
            "how to evaluate extraordinary claims with evidence discipline",
            "signal vs noise in unexplained aerial event reporting",
            "cognitive biases that shape interpretation of anomalous data"
        ],
        "mythology": [
            "myth structures that still shape modern storytelling",
            "symbolic archetypes and their practical cultural impact",
            "cross-cultural mythology patterns and interpretation"
        ],
        "biotech": [
            "biotech innovation cycles and regulatory trade-offs",
            "how lab-to-market timelines shape product strategy",
            "risk communication in emerging biotech narratives"
        ],
        "mathematics": [
            "how mathematical modeling improves everyday decisions",
            "intuition traps in probability and statistics",
            "building proof-style thinking for clear reasoning"
        ],
        "dogs": [
            "behavior training habits that improve dog-owner communication",
            "daily routines for healthy canine energy management",
            "how environment design affects dog behavior outcomes"
        ],
        "cats": [
            "environmental enrichment strategies for indoor cats",
            "understanding feline behavior signals in daily care",
            "habit routines that reduce stress for cats and owners"
        ],
        "birds": [
            "bird behavior cues and practical observation techniques",
            "urban habitats and how birds adapt to noise",
            "field-note habits for improving bird identification"
        ],
        "marine life": [
            "ocean ecosystem feedback loops and resilience",
            "human activity impacts on marine biodiversity",
            "conservation strategies that balance ecology and livelihoods"
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
