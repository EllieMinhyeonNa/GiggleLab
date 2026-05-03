import SwiftUI

struct EmojisListView: View {
    let options: [GiggleEmojiOption]
    @Binding var selectedEmoji: String?
    var onSelect: (GiggleEmojiOption) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options) { option in
                Button {
                    selectedEmoji = option.moodEmoji
                    onSelect(option)
                } label: {
                    EmojiIcon(assetName: option.assetName, fallbackEmoji: option.moodEmoji)
                        .frame(width: 44, height: 44)
                        .background(Theme.keyBackground)
                        .clipShape(Circle())
                        .overlay {
                            if selectedEmoji == option.moodEmoji {
                                Circle()
                                    .stroke(Theme.primaryYellow, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(red: 1.0, green: 0.949, blue: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

private struct EmojiIcon: View {
    let assetName: String
    let fallbackEmoji: String

    private var uiImage: UIImage? {
        // Try UIImage(named:) first (for asset catalog images)
        if let img = UIImage(named: assetName) {
            return img
        }
        // Try loading from bundle resources
        if let url = Bundle.main.url(forResource: assetName, withExtension: "png"),
           let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        // Try without extension in case it's already included
        if let url = Bundle.main.url(forResource: assetName, withExtension: nil),
           let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        return nil
    }

    var body: some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .padding(5)
        } else {
            Text(fallbackEmoji)
                .font(.system(size: 26))
        }
    }
}

#Preview {
    EmojisListView(
        options: [
            .init(id: "laughing", moodEmoji: "😆", assetName: "Laughing GiggleBee"),
            .init(id: "pleading", moodEmoji: "🥺", assetName: "Pleading GiggleBee"),
            .init(id: "loving", moodEmoji: "🥰", assetName: "Loving GiggleBee"),
            .init(id: "crying", moodEmoji: "😭", assetName: "Crying GiggleBee"),
            .init(id: "excited", moodEmoji: "😮", assetName: "Excited GiggleBee"),
            .init(id: "nervous", moodEmoji: "😅", assetName: "Nervous GiggleBee"),
            .init(id: "surprised", moodEmoji: "😂", assetName: "Surprised GiggleBee")
        ],
        selectedEmoji: .constant("😂"),
        onSelect: { _ in }
    )
}

