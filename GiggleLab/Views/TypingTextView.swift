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

    /// Font for the embedded `UITextView` (also drives line-height math for dynamic sizing).
    var font: UIFont = .systemFont(ofSize: Theme.composerInputFontSize, weight: .medium)
    /// When set, called with **visual** line count (wrapping counts as multiple lines). Used for 40↔60 composer height.
    var onVisualLineCountChange: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = font
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
            context.coordinator.applyVerticalContentInsets(to: tv)
            context.coordinator.reportVisualLineCount(for: tv)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        uiView.font = font

        if uiView.text != text {
            uiView.text = text
            let len = (uiView.text as NSString).length
            uiView.selectedRange = Self.clampedSelection(uiView.selectedRange, textLength: len)
        }

        var selectionAfterIntent: NSRange?
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
            selectionAfterIntent = uiView.selectedRange
        }

        // One main-queue hop: avoids writing SwiftUI bindings from `updateUIView` and cuts duplicate async layout work.
        DispatchQueue.main.async {
            if let newSelection = selectionAfterIntent {
                context.coordinator.isProgrammaticSelection = false
                selectedUTF16Range = newSelection
                textIntent = nil
            }
            context.coordinator.applyVerticalContentInsets(to: uiView)
            context.coordinator.reportVisualLineCount(for: uiView)
        }
    }

    /// Approximate visual line count for wrapping, **without** touching `layoutManager` (that forces TextKit 1 compatibility on modern `UITextView`).
    static func visualLineCount(for textView: UITextView) -> Int {
        let w = textView.bounds.width
            - textView.textContainerInset.left
            - textView.textContainerInset.right
            - textView.textContainer.lineFragmentPadding * 2
        guard w > 1 else { return 0 }
        let storage = textView.text ?? ""
        if storage.isEmpty { return 0 }
        let font = textView.font ?? .systemFont(ofSize: Theme.composerInputFontSize)
        let lineH = max(font.lineHeight, 1)
        let constraint = CGSize(width: max(1, w), height: .greatestFiniteMagnitude)
        let h = (storage as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
        return Int(ceil(h / lineH))
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
        private var lastReportedLineCount: Int?

        init(_ parent: TypingTextView) {
            self.parent = parent
        }

        func reportVisualLineCount(for textView: UITextView) {
            guard let onChange = parent.onVisualLineCountChange else { return }
            textView.layoutIfNeeded()
            let n = TypingTextView.visualLineCount(for: textView)
            let effective = max(1, n)
            if lastReportedLineCount != effective {
                lastReportedLineCount = effective
                onChange(effective)
            }
        }

        /// Vertically centers the laid-out text block inside the fixed SwiftUI height (40 / 60).
        func applyVerticalContentInsets(to textView: UITextView) {
            let h = textView.bounds.height
            let w = textView.bounds.width
            guard h > 1, w > 1 else { return }

            let prevInset = textView.textContainerInset

            // Measure intrinsic height with **no vertical** inset (horizontal unchanged).
            textView.textContainerInset = UIEdgeInsets(
                top: 0,
                left: prevInset.left,
                bottom: 0,
                right: prevInset.right
            )
            textView.layoutIfNeeded()

            let fitW = max(1, w - prevInset.left - prevInset.right)
            let fitting = CGSize(width: fitW, height: .greatestFiniteMagnitude)
            let naturalH = textView.sizeThatFits(fitting).height

            let contentH = min(naturalH, h)
            let pad = max(0, (h - contentH) / 2)
            textView.textContainerInset = UIEdgeInsets(
                top: pad,
                left: prevInset.left,
                bottom: pad,
                right: prevInset.right
            )

            if naturalH <= h + 0.5 {
                textView.contentOffset = CGPoint(x: textView.contentOffset.x, y: 0)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            applyVerticalContentInsets(to: textView)
            reportVisualLineCount(for: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isProgrammaticSelection else { return }
            parent.selectedUTF16Range = textView.selectedRange
        }
    }
}
