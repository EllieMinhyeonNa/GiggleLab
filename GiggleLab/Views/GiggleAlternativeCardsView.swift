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
                HStack(alignment: .center, spacing: 12) {
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        onTapArrow(index)
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.keyDark)
                            .frame(width: 36, height: 36)
                            .background(Theme.paleYellow)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
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
