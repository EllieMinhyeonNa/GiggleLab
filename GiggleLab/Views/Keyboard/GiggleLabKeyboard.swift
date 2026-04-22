import SwiftUI

struct GiggleLabKeyboard: View {
    @Binding var text: String
    @Binding var screen: KeyboardScreenMode
    @Binding var isShiftOneShot: Bool
    @Binding var isCapsLock: Bool

    var body: some View {
        GeometryReader { geo in
            let scale = max(geo.size.width / 360, 0.85)
            let w = Theme.letterKeyWidth * scale
            let h = Theme.keyHeight * scale

            VStack(spacing: Theme.rowSpacing * scale) {
                switch screen {
                case .letters:
                    letterRows(scale: scale, keyWidth: w, keyHeight: h)
                case .numbers:
                    numberRows(scale: scale, keyWidth: w, keyHeight: h)
                case .emoji:
                    emojiRow(scale: scale, keyHeight: h)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6 * scale)
            .padding(.top, 10 * scale)
            .padding(.bottom, 8 * scale)
        }
        .frame(height: keyboardStackHeight, alignment: .top)
    }

    private var keyboardStackHeight: CGFloat {
        switch screen {
        case .letters, .numbers: return 260
        case .emoji: return 210
        }
    }

    // MARK: - Letters (QWERTY)

    private func letterRows(scale: CGFloat, keyWidth: CGFloat, keyHeight: CGFloat) -> some View {
        let row1 = Array("qwertyuiop")
        let row2 = Array("asdfghjkl")
        let row3 = Array("zxcvbnm")

        return VStack(spacing: Theme.rowSpacing * scale) {
            HStack(spacing: Theme.keySpacing * scale) {
                ForEach(Array(row1.enumerated()), id: \.offset) { index, ch in
                    let hint = index == 9 ? "0" : "\(index + 1)"
                    letterKey(
                        char: ch,
                        numberHint: hint,
                        keyWidth: keyWidth,
                        keyHeight: keyHeight,
                        scale: scale
                    )
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                Spacer().frame(width: 17 * scale)
                ForEach(row2, id: \.self) { ch in
                    simpleLetterKey(ch, keyWidth: keyWidth, keyHeight: keyHeight, scale: scale)
                }
                Spacer().frame(width: 17 * scale)
            }
            HStack(spacing: Theme.keySpacing * scale) {
                functionKey(width: 46 * scale, height: keyHeight, scale: scale) {
                    Image(systemName: isCapsLock ? "capslock.fill" : "shift.fill")
                        .font(.system(size: 18 * scale))
                        .foregroundStyle(shiftActive ? Theme.keyDark : Theme.keyDark.opacity(0.55))
                } action: {
                    toggleShift()
                }
                ForEach(row3, id: \.self) { ch in
                    simpleLetterKey(ch, keyWidth: keyWidth, keyHeight: keyHeight, scale: scale)
                }
                functionKey(width: 46 * scale, height: keyHeight, scale: scale) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18 * scale))
                } action: {
                    deleteChar()
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                specialPill("?123", keyHeight: keyHeight, scale: scale) {
                    screen = .numbers
                    isShiftOneShot = false
                }
                functionKey(width: 30 * scale, height: keyHeight, scale: scale) {
                    Text(",")
                        .font(.system(size: 22 * scale))
                } action: {
                    insert(",")
                }
                simpleKey(title: "😀", keyWidth: 30 * scale, keyHeight: keyHeight, scale: scale, background: Theme.keyBackground) {
                    screen = .emoji
                }
                spaceKey(width: 125 * scale, height: keyHeight, scale: scale)
                functionKey(width: 30 * scale, height: keyHeight, scale: scale) {
                    Text(".")
                        .font(.system(size: 22 * scale))
                } action: {
                    insert(".")
                }
                returnKey(width: 47 * scale, height: keyHeight, scale: scale)
            }
        }
    }

    private var shiftActive: Bool {
        isShiftOneShot || isCapsLock
    }

    /// Cycles: off → one uppercase next key → caps lock → off (same idea as iOS shift).
    private func toggleShift() {
        if isCapsLock {
            isCapsLock = false
            isShiftOneShot = false
        } else if isShiftOneShot {
            isCapsLock = true
            isShiftOneShot = false
        } else {
            isShiftOneShot = true
        }
    }

    // MARK: - Numbers / symbols

    private func numberRows(scale: CGFloat, keyWidth: CGFloat, keyHeight: CGFloat) -> some View {
        let row1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        let row2 = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
        let row3 = [".", ",", "?", "!", "'"]

        return VStack(spacing: Theme.rowSpacing * scale) {
            HStack(spacing: Theme.keySpacing * scale) {
                ForEach(row1, id: \.self) { s in
                    symbolKey(s, keyWidth: keyWidth, keyHeight: keyHeight, scale: scale)
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                ForEach(row2, id: \.self) { s in
                    symbolKey(s, keyWidth: keyWidth, keyHeight: keyHeight, scale: scale)
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                specialPill("ABC", keyHeight: keyHeight, scale: scale) {
                    screen = .letters
                }
                ForEach(row3, id: \.self) { s in
                    symbolKey(s, keyWidth: keyWidth, keyHeight: keyHeight, scale: scale)
                }
                Spacer(minLength: 0)
                functionKey(width: 46 * scale, height: keyHeight, scale: scale) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18 * scale))
                } action: {
                    deleteChar()
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                specialPill("?123", keyHeight: keyHeight, scale: scale) {
                    screen = .numbers
                }
                functionKey(width: 30 * scale, height: keyHeight, scale: scale) {
                    Text(",")
                        .font(.system(size: 22 * scale))
                } action: { insert(",") }
                simpleKey(title: "😀", keyWidth: 30 * scale, keyHeight: keyHeight, scale: scale, background: Theme.keyBackground) {
                    screen = .emoji
                }
                spaceKey(width: 125 * scale, height: keyHeight, scale: scale)
                functionKey(width: 30 * scale, height: keyHeight, scale: scale) {
                    Text(".")
                        .font(.system(size: 22 * scale))
                } action: { insert(".") }
                returnKey(width: 47 * scale, height: keyHeight, scale: scale)
            }
        }
    }

    // MARK: - Emoji

    private func emojiRow(scale: CGFloat, keyHeight: CGFloat) -> some View {
        let emojis = ["😀", "😂", "🥹", "😍", "😉", "👍", "🙏", "✨", "🔥", "❤️"]
        return VStack(spacing: 12 * scale) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * scale), count: 5), spacing: Theme.rowSpacing * scale) {
                ForEach(emojis, id: \.self) { e in
                    Button {
                        insert(e)
                    } label: {
                        Text(e)
                            .font(.system(size: 28 * scale))
                            .frame(maxWidth: .infinity)
                            .frame(height: keyHeight * 0.9)
                            .background(Theme.keyBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: Theme.keySpacing * scale) {
                specialPill("ABC", keyHeight: keyHeight, scale: scale) {
                    screen = .letters
                }
                Spacer()
                functionKey(width: 46 * scale, height: keyHeight, scale: scale) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18 * scale))
                } action: {
                    deleteChar()
                }
            }
        }
    }

    // MARK: - Keys

    private func letterKey(char: Character, numberHint: String, keyWidth: CGFloat, keyHeight: CGFloat, scale: CGFloat) -> some View {
        Button {
            typeLetter(char)
        } label: {
            Text(String(char))
                .font(.system(size: 22 * scale))
                .foregroundStyle(Theme.keyDark)
                .frame(width: keyWidth, height: keyHeight, alignment: .center)
                .background(Theme.keyBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Text(numberHint)
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundStyle(Theme.neutralSecondary)
                        .padding(.trailing, 2 * scale)
                        .padding(.top, 2 * scale)
                }
        }
        .buttonStyle(.plain)
    }

    private func simpleLetterKey(_ char: Character, keyWidth: CGFloat, keyHeight: CGFloat, scale: CGFloat) -> some View {
        Button {
            typeLetter(char)
        } label: {
            Text(String(char))
                .font(.system(size: 22 * scale))
                .foregroundStyle(Theme.keyDark)
                .frame(width: keyWidth, height: keyHeight)
                .background(Theme.keyBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func symbolKey(_ s: String, keyWidth: CGFloat, keyHeight: CGFloat, scale: CGFloat) -> some View {
        Button {
            insert(s)
        } label: {
            Text(s)
                .font(.system(size: 20 * scale))
                .foregroundStyle(Theme.keyDark)
                .frame(width: keyWidth, height: keyHeight)
                .background(Theme.keyBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func simpleKey(title: String, keyWidth: CGFloat, keyHeight: CGFloat, scale: CGFloat, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22 * scale))
                .frame(width: keyWidth, height: keyHeight)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func functionKey(width: CGFloat, height: CGFloat, scale: CGFloat, @ViewBuilder label: () -> some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(Theme.keyDark)
                .frame(width: width, height: height)
                .background(Theme.lightYellow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func spaceKey(width: CGFloat, height: CGFloat, scale: CGFloat) -> some View {
        Button {
            insert(" ")
        } label: {
            Theme.keyBackground
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func returnKey(width: CGFloat, height: CGFloat, scale: CGFloat) -> some View {
        Button {
            insert("\n")
        } label: {
            Image(systemName: "return.left")
                .font(.system(size: 18 * scale))
                .foregroundStyle(Theme.keyDark)
                .frame(width: width, height: height)
                .background(Theme.returnKeyYellow)
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func specialPill(_ title: String, keyHeight: CGFloat, scale: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundStyle(Theme.keyDark)
                .padding(.horizontal, Theme.paddingMedium * scale)
                .frame(height: keyHeight)
                .background(Theme.paleYellow)
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input

    private func typeLetter(_ char: Character) {
        let lower = String(char)
        let out: String = {
            if isCapsLock || isShiftOneShot {
                return lower.uppercased()
            }
            return lower
        }()
        text.append(contentsOf: out)
        if isShiftOneShot {
            isShiftOneShot = false
        }
    }

    private func insert(_ s: String) {
        text.append(contentsOf: s)
    }

    private func deleteChar() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }
}
