import Foundation

/// Service for interacting with Google Gemini API
actor GeminiService {
    static let shared = GeminiService()

    private init() {}

    // Rate limiting
    private var requestCount = 0
    private var lastResetTime = Date()
    private let maxRequestsPerMinute = 15

    /// GiggleBee tone definitions
    enum GiggleBeeTone {
        case crying, excited, laughing, loving, nervous, pleading, surprised

        var promptDefinition: String {
            switch self {
            case .crying:
                return "TONE: Dramatic devastation with attitude. Not quiet sadness — loud, almost indignant grief. The energy is 'I cannot believe this happened to me.' Write with emotional intensity, like the world has personally wronged them. Avoid passive or gentle phrasing."
            case .excited:
                return "TONE: Stunned into excitement — overwhelmed to the point of going blank. Less 'yay!' and more 'I literally cannot process this right now.' High energy expressed through disbelief, not cheerleading. Fragmented thoughts, trailing off, or all-caps moments fit here."
            case .laughing:
                return "TONE: Full body laughter, completely unhinged. Not a chuckle — the kind where you can't finish your sentence. Chaotic, breathless energy. Interrupted thoughts, trailing 'haha's mid-sentence, or absurdist humor all work well."
            case .loving:
                return "TONE: Soft, warm, genuinely tender. Not flirty or performative — more like a quiet 'I'm so happy you exist.' Sincere and unhurried. Avoid exclamation-heavy or over-the-top phrasing. The warmth should feel earned, not announced."
            case .nervous:
                return "TONE: Trying to hold it together while clearly not holding it together. Awkward, self-aware, slightly self-deprecating. 'Ha ha everything is fine (it's not fine)' energy. Hedging words, over-explaining, or nervous laughter mid-sentence all fit."
            case .pleading:
                return "TONE: Maximally soft power — gently irresistible, not demanding. This person knows exactly how endearing they're being and is deploying it strategically. Hopeful, sweet, a little vulnerable. Avoid whining — the pleading should feel charming, not desperate."
            case .surprised:
                return "TONE: Clean, pure shock — no layer on top yet. They haven't processed enough to react with feeling. '...wait, what?' energy rather than excitement or fear. Short, stunned phrasing. Trailing off or disbelief works well here."
            }
        }

        var emoji: String {
            switch self {
            case .crying: return "😢"
            case .excited: return "🤩"
            case .laughing: return "😂"
            case .loving: return "🥰"
            case .nervous: return "😅"
            case .pleading: return "🥺"
            case .surprised: return "😯"
            }
        }
    }

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

    /// Three expressive rewrites of `text`, steered by a single `tone` and the composer's target language.
    /// Response must be a JSON array of exactly three strings (parsed after the model returns).
    func generateExpressiveAlternatives(
        text: String,
        tone: GiggleBeeTone,
        targetLanguage: String,
        style: TranslationStyle = .playful
    ) async throws -> [String] {
        try await checkRateLimit()
        let prompt = buildAlternativesPrompt(
            text: text,
            tone: tone,
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
        tone: GiggleBeeTone,
        language: String,
        style: TranslationStyle
    ) -> String {
        let toneHint: String
        switch style {
        case .funny:     toneHint = "Lean into wit and wordplay where it fits naturally."
        case .casual:    toneHint = "Keep it warm and conversational, like texting a friend."
        case .emojiRich: toneHint = "Weave in a few well-chosen emojis beyond the mood emoji."
        case .playful:   toneHint = "Playful and vivid — a little dramatic or funny where it helps."
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        You are GiggleLab. Rewrite the user's message as three expressive alternatives.

        USER_MESSAGE:
        \(trimmed)

        \(tone.promptDefinition)

        STYLE_HINT: \(toneHint)

        OUTPUT_LANGUAGE: Write all three alternatives entirely in \(language).

        RULES:
        - Each alternative must express the SAME core meaning as USER_MESSAGE.
        - SACRED ELEMENTS: Never remove, replace, or paraphrase proper nouns, names, places,
          or specific references from the original message.
          Example: if the message mentions "Griffin", "Mars", or "Tuesday",
          every alternative must keep them word-for-word.
        - Each must feel like a DISTINCTLY different angle or voice — not three near-duplicates.
          Think of it as: casual retelling / emotional peak / clever or understated version.
        - Write like a real text message — short, punchy, and natural.
          Fragments, lowercase, and trailing off are all fine.
          Never write full formal sentences when a fragment would feel more human.
        - Length should roughly match the original message. No padding.
        - No numbering, bullets, labels, or preamble.

        Return ONLY valid JSON: exactly one array of exactly three strings.
        Example format: ["...","...","..."]
        Escape any internal double quotes with backslash. No markdown fences.
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
