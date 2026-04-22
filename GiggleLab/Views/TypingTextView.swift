import SwiftUI
import UIKit

/// One-shot commands for the embedded `UITextView` (select all, or move the caret/selection after a programmatic edit).
struct TypingTextIntent: Equatable {
    enum Kind: Equatable {
        case selectAll
        case setSelectionUTF16(NSRange)
    }

    let id: UUID
    let kind: Kind

    init(_ kind: Kind) {
        self.id = UUID()
        self.kind = kind
    }

    static func == (lhs: TypingTextIntent, rhs: TypingTextIntent) -> Bool {
        lhs.id == rhs.id
    }
}

/// Multiline field that accepts the Simulator / hardware keyboard while keeping the software keyboard hidden
/// so your custom in-app keyboard remains the only on-screen keyboard.
struct TypingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedUTF16Range: NSRange
    @Binding var textIntent: TypingTextIntent?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        tv.textColor = .black
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = true
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.spellCheckingType = .yes

        tv.inputView = UIView(frame: .zero)
        tv.reloadInputViews()

        tv.text = text
        tv.selectedRange = Self.clampedSelection(tv.selectedRange, textLength: (tv.text as NSString).length)

        DispatchQueue.main.async {
            tv.becomeFirstResponder()
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
            let len = (uiView.text as NSString).length
            uiView.selectedRange = Self.clampedSelection(uiView.selectedRange, textLength: len)
        }

        if let intent = textIntent, intent.id != context.coordinator.lastAppliedIntentID {
            context.coordinator.lastAppliedIntentID = intent.id
            context.coordinator.isProgrammaticSelection = true
            let len = (uiView.text as NSString).length
            switch intent.kind {
            case .selectAll:
                uiView.selectedRange = NSRange(location: 0, length: len)
            case .setSelectionUTF16(let r):
                uiView.selectedRange = Self.clampedSelection(r, textLength: len)
            }
            context.coordinator.isProgrammaticSelection = false
            selectedUTF16Range = uiView.selectedRange
            DispatchQueue.main.async {
                textIntent = nil
            }
        }
    }

    private static func clampedSelection(_ range: NSRange, textLength: Int) -> NSRange {
        var r = range
        if r.location == NSNotFound {
            return NSRange(location: textLength, length: 0)
        }
        if r.location > textLength {
            r.location = textLength
            r.length = 0
        }
        if NSMaxRange(r) > textLength {
            r.length = max(0, textLength - r.location)
        }
        return r
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TypingTextView
        var lastAppliedIntentID: UUID?
        var isProgrammaticSelection = false

        init(_ parent: TypingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isProgrammaticSelection else { return }
            parent.selectedUTF16Range = textView.selectedRange
        }
    }
}
