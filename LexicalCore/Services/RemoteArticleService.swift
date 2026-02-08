import Foundation

public enum RemoteArticleServiceError: Error, LocalizedError {
    case missingEndpoint
    case invalidResponse
    case httpError(statusCode: Int, payload: String)
    case emptyContent

    public var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Missing LLM endpoint configuration."
        case .invalidResponse:
            return "Invalid LLM response payload."
        case let .httpError(statusCode, payload):
            return "LLM request failed (\(statusCode)): \(payload)"
        case .emptyContent:
            return "LLM response did not contain article content."
        }
    }
}

/// HTTP-backed LLM provider (OpenAI-compatible payload by default).
public actor RemoteArticleService: ArticleLLMProvider {
    public let endpoint: URL
    public let apiKey: String?
    public let model: String
    private let session: URLSession

    public init(
        endpoint: URL,
        apiKey: String? = nil,
        model: String = "gpt-4o-mini",
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public static func fromEnvironment() -> RemoteArticleService? {
        let env = ProcessInfo.processInfo.environment
        guard let endpointRaw = env["LEXICAL_LLM_ENDPOINT"],
              let endpoint = URL(string: endpointRaw) else {
            return nil
        }

        let key = env["LEXICAL_LLM_API_KEY"] ?? env["OPENAI_API_KEY"]
        let model = env["LEXICAL_LLM_MODEL"] ?? "gpt-4o-mini"
        return RemoteArticleService(endpoint: endpoint, apiKey: key, model: model)
    }

    public func generateContent(prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are an expert ESL content generator."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteArticleServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let payload = String(data: data, encoding: .utf8) ?? "<unreadable>"
            throw RemoteArticleServiceError.httpError(statusCode: http.statusCode, payload: payload)
        }

        guard let content = parseContent(from: data),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RemoteArticleServiceError.emptyContent
        }

        return content
    }

    private func parseContent(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let content = json["content"] as? String {
            return content
        }
        if let text = json["text"] as? String {
            return text
        }

        if let title = json["title"] as? String {
            let body = (json["body_text"] as? String) ?? (json["body"] as? String) ?? ""
            return "\(title)\n\n\(body)"
        }

        if let choices = json["choices"] as? [[String: Any]] {
            for choice in choices {
                if let text = choice["text"] as? String, !text.isEmpty {
                    return text
                }
                if let message = choice["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   !content.isEmpty {
                    return content
                }
            }
        }

        if let output = json["output"] as? [[String: Any]] {
            for chunk in output {
                if let content = chunk["content"] as? String, !content.isEmpty {
                    return content
                }
            }
        }

        return String(data: data, encoding: .utf8)
    }
}
