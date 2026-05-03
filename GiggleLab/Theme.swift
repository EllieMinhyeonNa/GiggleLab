import SwiftUI

struct Theme {
    // MARK: - Colors

    static let primaryYellow = Color(hex: 0xFFBB00)
    static let lightYellow = Color(hex: 0xFFDF9A)
    static let emojiPillBackground = Color(hex: 0xFFBB00)
    static let paleYellow = Color(hex: 0xFFF8DA)
    static let returnKeyYellow = Color(hex: 0xFFC653)

    static let keyboardBackground = Color(hex: 0xEDEDED)
    static let textPrimary = Color.black
    static let textSecondary = Color.black.opacity(0.4)
    static let keyBackground = Color.white

    static let neutralSecondary = Color(hex: 0x49494A)
    static let homeIndicator = neutralSecondary

    static let keyDark = Color(hex: 0x1B1B1D)

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 12
    static let paddingLarge: CGFloat = 24

    // MARK: - Keyboard

    static let keyHeight: CGFloat = 42
    static let letterKeyWidth: CGFloat = 30
    static let keyCornerRadius: CGFloat = 6
    static let keySpacing: CGFloat = 5
    static let rowSpacing: CGFloat = 10
}
