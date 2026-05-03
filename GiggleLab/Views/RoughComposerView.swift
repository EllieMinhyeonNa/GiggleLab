import SwiftUI

struct RoughComposerView: View {
    var onBack: () -> Void

    @State private var message = "Test"
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

    private struct ToolBarTopAnchorKey: PreferenceKey {
        static var defaultValue: Anchor<CGRect>? = nil
        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = nextValue() ?? value
        }
    }

    private var emojisListHeight: CGFloat {
        // EmojisListView: each item 44pt, spacing 10pt, plus container padding 8pt top/bottom.
        let n = CGFloat(giggleEmojiOptions.count)
        return (n * 44) + ((n - 1) * 10) + 16
    }

    private var emojisListWidth: CGFloat {
        // EmojisListView: 44pt circle + 8pt padding on each side.
        44 + 16
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                textArea
                    .padding(.horizontal, Theme.paddingLarge)
                    .padding(.top, Theme.paddingSmall)

                Spacer(minLength: 0)

                if alternativeLines.isEmpty {
                    toolBar
                        .anchorPreference(key: ToolBarTopAnchorKey.self, value: .bounds) { $0 }
                }
                keyboardBlock
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlayPreferenceValue(ToolBarTopAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if showEmojisList, let anchor {
                    let toolBarFrame = proxy[anchor]
                    let bottomY = toolBarFrame.minY - 8
                    let centerY = bottomY - (emojisListHeight / 2)
                    let centerX = proxy.size.width - 10 - (emojisListWidth / 2)

                    EmojisListView(options: giggleEmojiOptions, selectedEmoji: $selectedEmoji) { option in
                        withAnimation(.easeOut(duration: 0.2)) {
                            showEmojisList = false
                        }
                        fetchAlternativesFromGemini(emoji: option.moodEmoji)
                    }
                    .position(x: centerX, y: centerY)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
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
        .onChange(of: message) { _, _ in
            // If the user edits/deletes text while alternatives are showing, dismiss the cards
            // and return to the keyboard. (This includes deleting the highlighted selection.)
            if !alternativeLines.isEmpty && !isLoadingAlternatives {
                // Avoid "Modifying state during view update" warnings by deferring the reset.
                DispatchQueue.main.async {
                    clearAlternativesAndSession()
                }
            }
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

    /// Runs after the user picks the single mood emoji; fills `alternativeLines` from Gemini (keyboard slot shows loading, then three cards).
    private func fetchAlternativesFromGemini(emoji: String) {
        let text = giggleSessionTextForAPI ?? message
        let lang = languageMapping[targetLanguage] ?? "English"
        isLoadingAlternatives = true
        alternativeLines = []
        selectedEmoji = emoji
        Task {
            do {
                let lines = try await GeminiService.shared.generateExpressiveAlternatives(
                    text: text,
                    moodEmoji: emoji,
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

        clearAlternativesAndSession()
    }

    private func clearAlternativesAndSession() {
        alternativeLines = []
        selectedEmoji = nil
        showEmojisList = false
        giggleSessionRange = nil
        giggleSessionTextForAPI = nil
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .padding(.leading, 20)
            .padding(.top, Theme.paddingSmall)
        }
    }

    private var textArea: some View {
        TypingTextView(
            text: $message,
            selectedUTF16Range: $composerUTF16Selection,
            textIntent: $textIntent
        )
            .frame(minHeight: 120, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.paddingMedium)
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
