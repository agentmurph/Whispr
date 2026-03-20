import Foundation

// MARK: - LLM Provider Protocol

/// Protocol for LLM backends that can process text (clean up, transform, translate).
protocol LLMProvider {
    /// Complete a prompt with an optional system prompt.
    func complete(prompt: String, systemPrompt: String) async throws -> String

    /// Test connectivity to the provider. Throws on failure.
    func testConnection() async throws
}

// MARK: - LLM Errors

enum LLMError: Error, LocalizedError {
    case noProviderConfigured
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case networkError(Error)
    case missingAPIKey
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noProviderConfigured: return "No LLM provider configured."
        case .invalidResponse: return "Invalid response from LLM."
        case .httpError(let code, let message): return "HTTP \(code): \(message)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .missingAPIKey: return "API key is required."
        case .invalidURL: return "Invalid URL."
        }
    }
}

// MARK: - Provider Type

enum LLMProviderType: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case ollama = "ollama"
    case openai = "openai"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .ollama: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .none, .ollama: return false
        case .openai, .anthropic: return true
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .none: return ""
        case .ollama: return "http://localhost:11434"
        case .openai: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        }
    }

    var defaultModel: String {
        switch self {
        case .none: return ""
        case .ollama: return "llama3.2"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-4-20250514"
        }
    }
}

// MARK: - Ollama Provider

/// Local LLM via Ollama HTTP API (localhost:11434).
struct OllamaProvider: LLMProvider {
    let baseURL: String
    let model: String

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMError.invalidResponse
        }

        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testConnection() async throws {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMError.invalidURL
        }

        let request = URLRequest(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: "Cannot reach Ollama")
        }
    }
}

// MARK: - OpenAI Provider

/// OpenAI-compatible API provider (works with OpenAI and compatible endpoints).
struct OpenAIProvider: LLMProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testConnection() async throws {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: "Authentication failed")
        }
    }
}

// MARK: - Anthropic Provider

/// Anthropic Messages API provider.
struct AnthropicProvider: LLMProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    func complete(prompt: String, systemPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testConnection() async throws {
        // Anthropic doesn't have a simple health endpoint, so we send a minimal request
        _ = try await complete(prompt: "Say OK", systemPrompt: "Reply with only: OK")
    }
}
