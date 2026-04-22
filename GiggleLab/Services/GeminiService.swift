import Foundation

/// Service for interacting with Google Gemini API
actor GeminiService {
    static let shared = GeminiService()

    private init() {}

    // Rate limiting
    private var requestCount = 0
    private var lastResetTime = Date()
    private let maxRequestsPerMinute = 15

    /// Translation style/tone options
    enum TranslationStyle {
        case funny       // Add humor and wit
        case casual      // Friendly, conversational
        case emojiRich   // Lots of emojis
        case playful     // Mix of all above (default for GiggleLab)
    }

    /// Translate text with AI-powered creativity
    /// - Parameters:
    ///   - text: The text to translate
    ///   - targetLanguage: Target language code (e.g., "Spanish", "Korean")
    ///   - style: The translation style/tone
    /// - Returns: Translated and enhanced text
    func translateWithGiggle(
        text: String,
        to targetLanguage: String,
        style: TranslationStyle = .playful
    ) async throws -> String {
        // Check rate limit
        try await checkRateLimit()

        // Build prompt
        let prompt = buildPrompt(text: text, language: targetLanguage, style: style)

        // Call API
        let response = try await callGeminiAPI(prompt: prompt)

        return response
    }

    /// Three expressive rewrites of `text`, steered by a single `moodEmoji` and the composer’s target language.
    /// Response must be a JSON array of exactly three strings (parsed after the model returns).
    func generateExpressiveAlternatives(
        text: String,
        moodEmoji: String,
        targetLanguage: String,
        style: TranslationStyle = .playful
    ) async throws -> [String] {
        try await checkRateLimit()
        let prompt = buildAlternativesPrompt(
            text: text,
            moodEmoji: moodEmoji,
            language: targetLanguage,
            style: style
        )
        let raw = try await callGeminiAPI(prompt: prompt)
        return try Self.parseThreeAlternatives(from: raw)
    }

    // MARK: - Private Methods

    private func checkRateLimit() async throws {
        let now = Date()

        // Reset counter every minute
        if now.timeIntervalSince(lastResetTime) >= 60 {
            requestCount = 0
            lastResetTime = now
        }

        // Check if we've hit the limit
        if requestCount >= maxRequestsPerMinute {
            throw GeminiError.rateLimitExceeded
        }

        requestCount += 1
    }

    private func buildPrompt(text: String, language: String, style: TranslationStyle) -> String {
        let styleInstructions: String

        switch style {
        case .funny:
            styleInstructions = """
            - Add clever wordplay or puns where appropriate
            - Make it witty and amusing
            - Keep the original meaning intact
            """
        case .casual:
            styleInstructions = """
            - Use casual, friendly language
            - Sound natural and conversational
            - Like talking to a friend
            """
        case .emojiRich:
            styleInstructions = """
            - Add relevant emojis throughout
            - Use 2-4 emojis that match the mood
            - Make it expressive and fun
            """
        case .playful:
            styleInstructions = """
            - Add humor and personality
            - Include 1-3 relevant emojis
            - Make it fun while keeping the meaning
            - Sound casual and friendly
            - Add creative flair where possible
            """
        }

        // Detect if source and target are the same language
        let isDetectedEnglish = text.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let isTargetEnglish = language.lowercased().contains("english")
        let isSameLanguage = isDetectedEnglish && isTargetEnglish

        let taskDescription = isSameLanguage
            ? "You are GiggleLab, a playful text enhancer. Rewrite the following text in \(language) with a fun, creative twist:"
            : "You are GiggleLab, a playful translation assistant. Translate the following text to \(language) with these instructions:"

        return """
        \(taskDescription)

        \(styleInstructions)

        Important:
        - Preserve the core meaning
        - Match cultural context for \(language)
        - If there are idioms, \(isSameLanguage ? "make them more fun and creative" : "translate them creatively")
        - Be concise - don't add extra sentences
        - Return ONLY the \(isSameLanguage ? "enhanced" : "translated") text, no explanations

        Text to \(isSameLanguage ? "enhance" : "translate"): "\(text)"
        """
    }

    private func buildAlternativesPrompt(
        text: String,
        moodEmoji: String,
        language: String,
        style: TranslationStyle
    ) -> String {
        let toneHint: String
        switch style {
        case .funny:
            toneHint = "Witty, clever, light wordplay where it fits."
        case .casual:
            toneHint = "Warm, conversational, like texting a friend."
        case .emojiRich:
            toneHint = "Rich with a few well-chosen emojis (not only the mood emoji)."
        case .playful:
            toneHint = "Playful, vivid, a little dramatic or funny where it helps—still believable."
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        You are GiggleLab. The user wrote a short message and picked ONE mood emoji to steer tone and nuance.

        USER_MESSAGE (verbatim):
        \(trimmed)

        MOOD_EMOJI (single character; interpret its feeling and intensity for all three lines):
        \(moodEmoji)

        OUTPUT_LANGUAGE (write all three alternatives entirely in this language):
        \(language)

        Style: \(toneHint)
        Keep the same core meaning and intent as USER_MESSAGE. Each line should feel distinctly expressive—different voice or angle, not three near-duplicates. No numbering, no bullets, no preamble.

        Return ONLY valid JSON: exactly one array of exactly three strings, e.g. ["...","...","..."].
        Escape any double quotes inside strings with backslash. No markdown fences, no keys, no explanation outside the JSON.
        """
    }

    /// Expects a JSON array of strings; tolerates markdown fences or leading prose if the array is still parseable.
    private static func parseThreeAlternatives(from raw: String) throws -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromJSON = try? decodeThreeStrings(from: trimmed) {
            return fromJSON
        }
        guard let open = trimmed.firstIndex(of: "["),
              let close = trimmed.lastIndex(of: "]"),
              open < close else {
            throw GeminiError.invalidResponse
        }
        let slice = String(trimmed[open ... close])
        return try decodeThreeStrings(from: slice)
    }

    private static func decodeThreeStrings(from jsonFragment: String) throws -> [String] {
        guard let data = jsonFragment.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        let decoded: Any
        do {
            decoded = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw GeminiError.invalidResponse
        }
        guard let arr = decoded as? [String] else {
            throw GeminiError.invalidResponse
        }
        let cleaned = arr
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard cleaned.count >= 3 else {
            throw GeminiError.invalidResponse
        }
        return Array(cleaned.prefix(3))
    }

    private func callGeminiAPI(prompt: String) async throws -> String {
        // Check API key
        guard Config.geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE" else {
            throw GeminiError.missingAPIKey
        }

        // Build URL
        let urlString = "\(Config.geminiAPIEndpoint)?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimitExceeded
            }
            let detail = Self.apiErrorDetail(from: data)
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: detail)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses Google API `error.message` when present (helps debug wrong model / URL).
    private static func apiErrorDetail(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String,
              !message.isEmpty else {
            return nil
        }
        return message
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured. Please add your Gemini API key to Config.swift"
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Unexpected response from API"
        case .rateLimitExceeded:
            return "⏳ Too many gigglers right now! Please wait a moment and try again."
        case .apiError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "API error (\(statusCode)): \(message)"
            }
            return "API error (code: \(statusCode)). Please try again."
        }
    }
}
