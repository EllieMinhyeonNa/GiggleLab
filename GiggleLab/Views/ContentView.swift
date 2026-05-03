import SwiftUI

struct ContentView: View {
    @State private var showComposer = true

    var body: some View {
        Group {
            if showComposer {
                RoughComposerView(onBack: { showComposer = false })
            } else {
                VStack(spacing: 20) {
                    Text("GiggleLab")
                        .font(.title.bold())
                    Text("Prototype home — open the composer to try the keyboard.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Open composer") {
                        showComposer = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

}

#Preview {
    ContentView()
}
