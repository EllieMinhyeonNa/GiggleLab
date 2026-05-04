import SwiftUI
import UIKit

/// Message model for chat display
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let isFromUser: Bool
}

/// Bottom edge of `chatHeader` in `railSpace` (same space as `VStack` + overlay).
private struct ProfileBottomRailYPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Top edge of `keyboardBlock` in `railSpace`.
private struct KeyboardTopRailYPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


struct RoughComposerView: View {
    var onBack: () -> Void

    @State private var message = ""
    @State private var keyboardScreen: KeyboardScreenMode = .letters
    @State private var isShiftOneShot = false
    @State private var isCapsLock = false
    @State private var targetLanguage = "Eng"
    @State private var showEmojisList = false
    @State private var showLanguagePicker = false
    @State private var selectedEmoji: String? = nil
    @State private var alternativeLines: [String] = []
    @State private var isLoadingAlternatives = false
    @State private var errorMessage: String?
    /// UTF-16 range in `message` mirrored from `TypingTextView` (used when swapping in an alternative).
    @State private var composerUTF16Selection = NSRange(location: 0, length: 0)
    @State private var textIntent: TypingTextIntent?
    /// Snapshot when **Get Giggling** was tapped: range to replace with an alternative, and text sent to Gemini (partial or full).
    @State private var giggleSessionRange: NSRange?
    @State private var giggleSessionTextForAPI: String?
    /// Laid-out line count from `TypingTextView` (1 = single line / empty slot; 2+ = expanded, height capped at max).
    @State private var composerVisualLineCount: Int = 1
    @State private var railProfileBottomY: CGFloat = 0
    @State private var railKeyboardTopY: CGFloat = 0
    @State private var messages: [ChatMessage] = []

    private let languages = ["Eng", "Esp", "Kor", "Fra"]
    private let languageMapping: [String: String] = [
        "Eng": "English",
        "Esp": "Spanish",
        "Kor": "Korean",
        "Fra": "French"
    ]

    // Order matches the Figma bar.
    private let giggleEmojiOptions: [GiggleEmojiOption] = [
        .init(id: "laughing", moodEmoji: "😆", assetName: "Laughing GiggleBee"),
        .init(id: "pleading", moodEmoji: "🥺", assetName: "Pleading GiggleBee"),
        .init(id: "loving", moodEmoji: "🥰", assetName: "Loving GiggleBee"),
        .init(id: "crying", moodEmoji: "😭", assetName: "Crying GiggleBee"),
        .init(id: "excited", moodEmoji: "😮", assetName: "Excited GiggleBee"),
        .init(id: "nervous", moodEmoji: "😅", assetName: "Nervous GiggleBee"),
        .init(id: "surprised", moodEmoji: "😂", assetName: "Surprised GiggleBee")
    ]

    private var emojisListWidth: CGFloat {
        // EmojisListView: 44pt circle + 8pt padding on each side.
        44 + 16
    }

    private var emojisListHeight: CGFloat {
        // EmojisListView: 7 items × 44pt + 6 gaps × 10pt + container padding 16pt (8pt top/bottom).
        let n = CGFloat(giggleEmojiOptions.count)
        return (n * 44) + ((n - 1) * 10) + 16
    }

    private var composerInputFieldHeight: CGFloat {
        composerVisualLineCount <= 1 ? Theme.composerInputMinHeight : Theme.composerInputMaxHeight
    }

    private var hasComposerText: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.chatSurface
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                chatHeader
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(
                                key: ProfileBottomRailYPreference.self,
                                value: g.frame(in: .named("railSpace")).maxY
                            )
                        }
                    )

                ScrollView {
                    VStack(spacing: 0) {
                        if messages.isEmpty {
                            Color.clear
                                .frame(minHeight: 120)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { msg in
                                    VStack(spacing: 6) {
                                        Text(formatTimestamp(msg.timestamp))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .center)

                                        HStack {
                                            Spacer()
                                            Text(msg.text)
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundStyle(Theme.textPrimary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(Theme.primaryYellow)
                                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                        }
                                    }
                                    .padding(.horizontal, Theme.paddingSmall)
                                }
                            }
                            .padding(.top, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

                composerInputRow

                if alternativeLines.isEmpty {
                    toolBar
                }

                keyboardBlock
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(
                                key: KeyboardTopRailYPreference.self,
                                value: g.frame(in: .named("railSpace")).minY
                            )
                        }
                    )
            }
            .coordinateSpace(name: "railSpace")
            .overlay(alignment: .topTrailing) {
                if showEmojisList {
                    emojiRailOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(ProfileBottomRailYPreference.self) { newY in
            scheduleRailMetricUpdate { if abs(railProfileBottomY - newY) > 0.5 { railProfileBottomY = newY } }
        }
        .onPreferenceChange(KeyboardTopRailYPreference.self) { newY in
            scheduleRailMetricUpdate { if abs(railKeyboardTopY - newY) > 0.5 { railKeyboardTopY = newY } }
        }
        .confirmationDialog("Translate to", isPresented: $showLanguagePicker, titleVisibility: .visible) {
            ForEach(languages, id: \.self) { code in
                Button(code) {
                    targetLanguage = code
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Oops!", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: message) { oldValue, newValue in
            // If the user edits/deletes text while alternatives are showing, dismiss the cards
            // and return to the keyboard. (This includes deleting the highlighted selection.)
            // BUT: Don't clear if the change came from applyAlternative (text got longer/replaced)
            if !alternativeLines.isEmpty && !isLoadingAlternatives {
                // Check if this was a user edit (typing/deleting) vs. programmatic replacement
                // If giggleSessionRange exists and the new text contains an alternative, it's from applyAlternative
                let isProgrammaticReplacement = alternativeLines.contains { newValue.contains($0) }

                if !isProgrammaticReplacement {
                    // Avoid "Modifying state during view update" warnings by deferring the reset.
                    DispatchQueue.main.async {
                        clearAlternativesAndSession()
                    }
                }
            }
        }
    }

    // MARK: - Send Message

    /// Sends the current message to the chat, adds timestamp, and resets the composer to default state
    private func handleSendMessage() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Create message with current Eastern Time
        let newMessage = ChatMessage(
            text: trimmed,
            timestamp: Date(),
            isFromUser: true
        )

        // Add to messages array
        messages.append(newMessage)

        // Reset composer to default state
        message = ""
        composerUTF16Selection = NSRange(location: 0, length: 0)
        clearAlternativesAndSession()
    }

    /// Formats timestamp in Eastern Time as "Today HH:mma" or "Yesterday HH:mma" or "MMM d HH:mma"
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/New_York")

        let easternCalendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            // Fallback if timezone not found
            formatter.dateFormat = "h:mma"
            return "Today \(formatter.string(from: date))"
        }

        var easternCalendarCopy = easternCalendar
        easternCalendarCopy.timeZone = easternTimeZone

        let isToday = easternCalendarCopy.isDateInToday(date)
        let isYesterday = easternCalendarCopy.isDateInYesterday(date)

        formatter.dateFormat = "h:mma"
        let timeString = formatter.string(from: date).lowercased()

        if isToday {
            return "Today \(timeString)"
        } else if isYesterday {
            return "Yesterday \(timeString)"
        } else {
            formatter.dateFormat = "MMM d"
            let dateString = formatter.string(from: date)
            return "\(dateString) \(timeString)"
        }
    }

    // MARK: - Giggle flow (one emoji → three alternatives in the keyboard slot)

    /// Opens the emoji rail. After the user picks **one** emoji, `alternativeLines` fills and `keyboardBlock` swaps the key grid for `GiggleAlternativeCardsView`.
    ///
    /// - If the user already highlighted a **non-empty** range, that selection is kept and only that substring is sent to Gemini.
    /// - If there is only a caret (no length), all text is selected and the full message is used.
    private func handleGetGiggling() {
        guard !message.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please type something first!"
            return
        }
        let ns = message as NSString
        let maxLen = ns.length
        let r = Self.clampedUTF16Range(composerUTF16Selection, maxLength: maxLen)

        let hasExplicitPartialHighlight = r.length > 0

        if hasExplicitPartialHighlight {
            giggleSessionRange = r
            giggleSessionTextForAPI = ns.substring(with: r)
        } else {
            giggleSessionRange = NSRange(location: 0, length: maxLen)
            giggleSessionTextForAPI = message
            textIntent = TypingTextIntent(.selectAll)
        }

        alternativeLines = []
        selectedEmoji = nil
        showEmojisList = true
    }

    /// Maps emoji to GiggleBeeTone based on the mood
    private func emojiToTone(_ emoji: String) -> GeminiService.GiggleBeeTone {
        switch emoji {
        case "😆": return .laughing
        case "🥺": return .pleading
        case "🥰": return .loving
        case "😭": return .crying
        case "😮": return .excited
        case "😅": return .nervous
        case "😂": return .surprised
        default: return .laughing  // fallback
        }
    }

    /// Runs after the user picks the single mood emoji; fills `alternativeLines` from Gemini (keyboard slot shows loading, then three cards).
    private func fetchAlternativesFromGemini(emoji: String) {
        let text = giggleSessionTextForAPI ?? message
        let lang = languageMapping[targetLanguage] ?? "English"
        isLoadingAlternatives = true
        alternativeLines = []
        selectedEmoji = emoji
        Task {
            do {
                let tone = emojiToTone(emoji)
                let lines = try await GeminiService.shared.generateExpressiveAlternatives(
                    text: text,
                    tone: tone,
                    targetLanguage: lang,
                    style: .playful
                )
                await MainActor.run {
                    alternativeLines = lines
                    isLoadingAlternatives = false
                }
            } catch {
                await MainActor.run {
                    isLoadingAlternatives = false
                    alternativeLines = []
                    giggleSessionRange = nil
                    giggleSessionTextForAPI = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Replaces the session range (partial or full from **Get Giggling**) with the chosen line, then highlights the inserted text and returns to the keyboard.
    private func applyAlternative(at index: Int) {
        guard alternativeLines.indices.contains(index) else { return }
        let replacement = alternativeLines[index]
        let ns = message as NSString
        let maxLen = ns.length

        var r = giggleSessionRange ?? composerUTF16Selection
        if r.location == NSNotFound {
            r = NSRange(location: 0, length: 0)
        }
        r = Self.clampedUTF16Range(r, maxLength: maxLen)

        if r.length == 0 {
            r = NSRange(location: 0, length: maxLen)
        }

        let newMessage = ns.replacingCharacters(in: r, with: replacement)
        message = String(newMessage)

        let newLength = (replacement as NSString).length
        let newSelection = NSRange(location: r.location, length: newLength)
        textIntent = TypingTextIntent(.setSelectionUTF16(newSelection))

        // Keep alternatives visible - don't clear until user edits the text
    }

    private func clearAlternativesAndSession() {
        alternativeLines = []
        selectedEmoji = nil
        showEmojisList = false
        giggleSessionRange = nil
        giggleSessionTextForAPI = nil
    }

    /// Applies rail layout numbers on the next run loop so we don’t mutate `@State` during preference propagation (reduces “accumulator after completion” noise).
    private func scheduleRailMetricUpdate(_ update: @escaping () -> Void) {
        DispatchQueue.main.async(execute: update)
    }

    private static func clampedUTF16Range(_ range: NSRange, maxLength: Int) -> NSRange {
        var r = range
        if r.location > maxLength {
            r.location = maxLength
            r.length = 0
        }
        if NSMaxRange(r) > maxLength {
            r.length = max(0, maxLength - r.location)
        }
        return r
    }

    /// Chat-style header (Figma `313:5477`): back, centered peer avatar + name, balanced trailing space.
    private var chatHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 88, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text("S")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.primaryYellow)
                    .clipShape(Circle())

                HStack(spacing: 4) {
                    Text("Serena")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 88, height: 1)
        }
        .padding(.horizontal, Theme.paddingSmall)
        .padding(.top, Theme.paddingSmall)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.chatSurface)
    }

    /// Pill composer row above the gray toolbar (empty by default; no placeholder in Figma).
    private var composerInputRow: some View {
        HStack(alignment: .center, spacing: Theme.paddingSmall) {
            Group {
                TypingTextView(
                    text: $message,
                    selectedUTF16Range: $composerUTF16Selection,
                    textIntent: $textIntent,
                    font: .systemFont(ofSize: Theme.composerInputFontSize, weight: .regular),
                    onVisualLineCountChange: { composerVisualLineCount = $0 }
                )
                .frame(height: composerInputFieldHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .stroke(Color(red: 16 / 255, green: 16 / 255, blue: 16 / 255).opacity(0.10), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, showEmojisList ? 68 : 0) // Make space for emoji bar (60pt width + 8pt gap)

            if !showEmojisList {
                Button {
                    handleSendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: Theme.composerSendIconSize, weight: .semibold))
                        .foregroundStyle(hasComposerText ? Theme.textPrimary : Color.white)
                        .frame(width: Theme.composerSendButtonSize, height: Theme.composerSendButtonSize)
                        .background(
                            Circle()
                                .fill(hasComposerText ? Theme.primaryYellow : Theme.keyboardBackground)
                        )
                        .shadow(
                            color: Color.black.opacity(hasComposerText ? 0.08 : 0),
                            radius: 5,
                            x: 0,
                            y: 0
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Send"))
                .disabled(!hasComposerText)
            }
        }
        .padding(.leading, Theme.paddingSmall)
        .padding(.trailing, Theme.paddingSmall)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    /// Right emoji rail only: does not participate in toolbar layout (Translate / Get Giggling unchanged).
    /// The bottom edge of the emoji bar aligns with the bottom edge of the text input box.
    private var emojiRailOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(alignment: .bottom, spacing: 0) {
                Spacer()

                EmojisListView(options: giggleEmojiOptions, selectedEmoji: $selectedEmoji) { option in
                    showEmojisList = false
                    fetchAlternativesFromGemini(emoji: option.moodEmoji)
                }
                .padding(.trailing, Theme.paddingSmall)
            }

            // Space for: toolbar (48pt) + text input (56pt) + padding (10pt each top/bottom) + keyboard
            Spacer()
                .frame(height: 348) // Adjust this to move emoji bar up/down
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var toolBar: some View {
        HStack(spacing: Theme.paddingMedium) {
            Button {
                showLanguagePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text("Translate to: ")
                        .foregroundStyle(Theme.textSecondary)
                    Text(targetLanguage)
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary.opacity(0.45))
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, Theme.paddingMedium)
                .frame(height: 42)
                .background(Theme.keyBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: Theme.paddingSmall)

            Button {
                handleGetGiggling()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Get Giggling")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.paddingMedium)
                .frame(height: 42)
                .frame(maxWidth: 160)
                .background(Theme.primaryYellow)
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isLoadingAlternatives)
        }
        .padding(.horizontal, Theme.paddingSmall)
        .padding(.vertical, 10)
        .background(Theme.keyboardBackground)
    }

    private var keyboardBlock: some View {
        VStack(spacing: 0) {
            if isLoadingAlternatives {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("Cooking up giggles…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .background(Theme.keyboardBackground)
            } else if alternativeLines.isEmpty {
                GiggleLabKeyboard(
                    text: $message,
                    screen: $keyboardScreen,
                    isShiftOneShot: $isShiftOneShot,
                    isCapsLock: $isCapsLock
                )
                .background(Theme.keyboardBackground)
            } else {
                VStack(spacing: 8) {
                    TopEmojiSelectionBarView(
                        options: giggleEmojiOptions,
                        selectedMoodEmoji: $selectedEmoji
                    ) { option in
                        fetchAlternativesFromGemini(emoji: option.moodEmoji)
                    }

                    GiggleAlternativeCardsView(lines: alternativeLines) { index in
                        applyAlternative(at: index)
                    }
                }
                .padding(.top, 16)
                .background(Theme.keyboardBackground)
            }

            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Theme.homeIndicator)
                .frame(width: 72, height: 4)
                .padding(.top, Theme.paddingSmall)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background(Theme.keyboardBackground)
        }
    }
}

// MARK: - Top emoji selection bar (Figma)

struct GiggleEmojiOption: Identifiable, Equatable {
    let id: String
    let moodEmoji: String
    let assetName: String
}

private struct TopEmojiSelectionBarView: View {
    /// Figma: 344×51 with 8pt inset on a 360pt canvas.
    private let screenHorizontalMargin: CGFloat = 8
    private let barHeight: CGFloat = 51
    private let barCornerRadius: CGFloat = 56

    /// Figma: selection ellipse 42×42, image ~33.336×33.336.
    private let emojiSlotSize: CGFloat = 42
    private let emojiIconSize: CGFloat = 36

    let options: [GiggleEmojiOption]
    @Binding var selectedMoodEmoji: String?
    var onSelect: (GiggleEmojiOption) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = selectedMoodEmoji == option.moodEmoji
                Button {
                    selectedMoodEmoji = option.moodEmoji
                    onSelect(option)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Theme.emojiPillBackground : .clear)
                            .frame(width: emojiSlotSize, height: emojiSlotSize)

                        EmojiIconForTopBar(assetName: option.assetName, fallbackEmoji: option.moodEmoji)
                            .frame(width: emojiIconSize, height: emojiIconSize)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.moodEmoji))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: barHeight)
        .background(
            RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                .fill(Theme.keyBackground)
        )
        .padding(.horizontal, screenHorizontalMargin)
    }
}

private struct EmojiIconForTopBar: View {
    let assetName: String
    let fallbackEmoji: String

    private var uiImage: UIImage? {
        if let img = UIImage(named: assetName) { return img }
        if let url = Bundle.main.url(forResource: assetName, withExtension: "png"),
           let img = UIImage(contentsOfFile: url.path) { return img }
        if let url = Bundle.main.url(forResource: assetName, withExtension: nil),
           let img = UIImage(contentsOfFile: url.path) { return img }
        return nil
    }

    var body: some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .padding(2)
        } else {
            Text(fallbackEmoji)
                .font(.system(size: 24))
        }
    }
}

#Preview {
    RoughComposerView(onBack: {})
}
