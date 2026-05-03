import SwiftUI

enum GiggleAlternativePlaceholder {
    /// Stub copy until you plug in an API. Uses the current composer text + tapped emoji.
    static func lines(for message: String, emoji: String) -> [String] {
        let base = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = base.isEmpty ? "…" : "“\(base)”"

        return [
            "\(emoji) \(quoted) — My stomach is growling like THUNDER. (placeholder)",
            "\(emoji) \(quoted) — lol… I’m so starving at this point it’s not even funny. (placeholder)",
            "\(emoji) \(quoted) — I am seconds away from eating everything in the fridge LOL. (placeholder)"
        ]
    }
}

struct GiggleAlternativeCardsView: View {
    let lines: [String]
    var onTapArrow: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 12) {
                    Text(line)
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(2)
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        onTapArrow(index)
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: 0xFFE18E))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                // Figma-style insets: 16px left + 16px top/bottom (kept even if text wraps).
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 16)
                .background(Theme.keyBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, Theme.paddingSmall)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.keyboardBackground)
    }
}

#Preview {
    GiggleAlternativeCardsView(
        lines: GiggleAlternativePlaceholder.lines(for: "I'm hungry", emoji: "😆"),
        onTapArrow: { _ in }
    )
}
