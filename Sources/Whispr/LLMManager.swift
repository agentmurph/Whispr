import Foundation
import SwiftUI

/// Manages the active LLM provider, configuration, and connectivity.
@MainActor
final class LLMManager: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing: Bool = false
    @Published var lastError: String?
    @Published var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus: Equatable {
        case unknown
        case testing
        case connected
        case failed(String)
    }

    // MARK: - Configuration (persisted via UserDefaults)

    @AppStorage("llm.providerType") var providerTypeRaw: String = LLMProviderType.none.rawValue
    @AppStorage("llm.model") var modelName: String = ""
    @AppStorage("llm.baseURL") var baseURL: String = ""

    /// API key stored separately — we use UserDefaults for simplicity but mark it.
    /// In production, Keychain would be better, but UserDefaults is fine for a local app.
    @AppStorage("llm.apiKey") var apiKey: String = ""

    var providerType: LLMProviderType {
        get { LLMProviderType(rawValue: providerTypeRaw) ?? .none }
        set {
            providerTypeRaw = newValue.rawValue
            // Set defaults for new provider type
            if baseURL.isEmpty || baseURL == LLMProviderType.ollama.defaultBaseURL
                || baseURL == LLMProviderType.openai.defaultBaseURL
                || baseURL == LLMProviderType.anthropic.defaultBaseURL {
                baseURL = newValue.defaultBaseURL
            }
            if modelName.isEmpty {
                modelName = newValue.defaultModel
            }
            connectionStatus = .unknown
        }
    }

    /// Whether an LLM provider is configured and available.
    var isConfigured: Bool {
        providerType != .none
    }

    // MARK: - Provider Instance

    /// Build the active provider from current config. Returns nil if none configured.
    var activeProvider: LLMProvider? {
        let type = providerType
        let url = baseURL.isEmpty ? type.defaultBaseURL : baseURL
        let model = modelName.isEmpty ? type.defaultModel : modelName

        switch type {
        case .none:
            return nil
        case .ollama:
            return OllamaProvider(baseURL: url, model: model)
        case .openai:
            return OpenAIProvider(baseURL: url, apiKey: apiKey, model: model)
        case .anthropic:
            return AnthropicProvider(baseURL: url, apiKey: apiKey, model: model)
        }
    }

    // MARK: - Complete

    /// Process text through the LLM. Returns nil if no provider configured.
    func complete(prompt: String, systemPrompt: String) async -> String? {
        guard let provider = activeProvider else { return nil }

        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        do {
            let result = try await provider.complete(prompt: prompt, systemPrompt: systemPrompt)
            return result
        } catch {
            lastError = error.localizedDescription
            print("LLM error: \(error)")
            return nil
        }
    }

    // MARK: - Test Connection

    func testConnection() async {
        guard let provider = activeProvider else {
            connectionStatus = .failed("No provider configured")
            return
        }

        connectionStatus = .testing

        do {
            try await provider.testConnection()
            connectionStatus = .connected
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }
    }
}
