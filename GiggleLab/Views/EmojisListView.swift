import SwiftUI

struct EmojisListView: View {
    let emojis: [String]
    @Binding var selectedEmoji: String?
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(emojis, id: \.self) { e in
                Button {
                    selectedEmoji = e
                    onSelect(e)
                } label: {
                    Text(e)
                        .font(.system(size: 26))
                        .frame(width: 44, height: 44)
                        .background(Theme.keyBackground)
                        .clipShape(Circle())
                        .overlay {
                            if selectedEmoji == e {
                                Circle()
                                    .stroke(Theme.primaryYellow, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Theme.emojiPillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    EmojisListView(
        emojis: ["😮", "😆", "😅", "🥰", "🥺", "😂", "😭"],
        selectedEmoji: .constant("😂"),
        onSelect: { _ in }
    )
}

