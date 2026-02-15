import Foundation

public enum ArticleStylePreference: String, CaseIterable, Codable, Sendable {
    case balanced
    case informative
    case fun
    case fresh

    public var title: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .informative:
            return "Informative"
        case .fun:
            return "Fun"
        case .fresh:
            return "Fresh Angle"
        }
    }

    public var subtitle: String {
        switch self {
        case .balanced:
            return "Mix insight, clarity, and practical takeaways."
        case .informative:
            return "Explain concepts deeply with evidence and structure."
        case .fun:
            return "Use vivid examples, storytelling, and engaging tone."
        case .fresh:
            return "Prioritize new perspectives and unexpected contrasts."
        }
    }

    public var promptDirective: String {
        switch self {
        case .balanced:
            return "Use a balanced style: clear explanation, engaging examples, and practical steps."
        case .informative:
            return "Use an informative style: rigorous explanation, precise definitions, and careful claims."
        case .fun:
            return "Use an engaging style: conversational rhythm, vivid scenarios, and memorable analogies."
        case .fresh:
            return "Use a novelty-first style: surprising angle, non-obvious comparisons, and original framing."
        }
    }
}
