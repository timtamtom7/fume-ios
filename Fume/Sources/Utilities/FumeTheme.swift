import SwiftUI

// MARK: - Design Tokens

/// iOS 26 Liquid Glass design system tokens
struct FumeTokens {
    // MARK: - Corner Radius
    /// Small elements: badges, chips, small buttons (min touch target)
    static let cornerRadiusSmall: CGFloat = 8
    /// Medium elements: cards, inputs, list rows
    static let cornerRadiusMedium: CGFloat = 12
    /// Large elements: sheets, modal content, feature cards
    static let cornerRadiusLarge: CGFloat = 16
    /// Extra-large elements: glass cards, primary containers
    static let cornerRadiusXLarge: CGFloat = 20
    /// Capsule buttons and pills
    static let cornerRadiusCapsule: CGFloat = 9999

    // MARK: - Font Sizes (minimum 11pt per iOS accessibility guidelines)
    /// Caption 2 - metadata, timestamps (11pt minimum)
    static let fontSizeCaption2: CGFloat = 11
    /// Caption - secondary metadata, labels (12pt)
    static let fontSizeCaption: CGFloat = 12
    /// Body Small - secondary text, descriptions (13pt)
    static let fontSizeBodySmall: CGFloat = 13
    /// Body - primary text (14pt)
    static let fontSizeBody: CGFloat = 14
    /// Body Large - emphasized body text (15pt)
    static let fontSizeBodyLarge: CGFloat = 15
    /// Subhead - section headers, card titles (16pt)
    static let fontSizeSubhead: CGFloat = 16
    /// Title - view titles, prominent headings (17pt)
    static let fontSizeTitle: CGFloat = 17
    /// Title 2 - section titles (20pt)
    static let fontSizeTitle2: CGFloat = 20
    /// Title 3 - screen titles (24pt)
    static let fontSizeTitle3: CGFloat = 24

    // MARK: - Spacing
    static let spacingXSmall: CGFloat = 4
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let spacingXLarge: CGFloat = 20
    static let spacingXXLarge: CGFloat = 24

    // MARK: - Touch Targets (minimum 44pt per iOS HIG)
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Fume Colors
struct FumeColors {
    static let background = Color(hex: "0a0a0b")
    static let surface = Color(hex: "141416")
    static let surfaceRaised = Color(hex: "1c1c1f")
    static let glassOverlay = Color(hex: "1e1e20").opacity(0.85)
    static let accent = Color(hex: "f59e0b")
    static let accentDim = Color(hex: "d97706")
    static let textPrimary = Color(hex: "f4f4f5")
    static let textSecondary = Color(hex: "a1a1aa")
    static let sourceHighlight = Color(hex: "f59e0b").opacity(0.15)
    static let border = Color(hex: "2a2a2e")
    static let divider = Color(hex: "27272a")
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback

enum FumeHaptic {
    /// Light impact - button taps, selections
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Medium impact - significant actions
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Heavy impact - major actions (destructive, etc.)
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Selection changed - picker changes, toggles
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Success notification
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Warning notification
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Error notification
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var padding: CGFloat = FumeTokens.spacingLarge
    var cornerRadius: CGFloat = FumeTokens.cornerRadiusXLarge

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(FumeColors.glassOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(FumeColors.border, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Glow Modifier
struct AmberGlow: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = FumeTokens.cornerRadiusXLarge

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(FumeColors.sourceHighlight)
                    .blur(radius: isActive ? 12 : 0)
                    .opacity(isActive ? 1 : 0)
            )
    }
}

// MARK: - Primary Button Style

struct FumePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: FumeTokens.fontSizeBodyLarge, weight: .semibold))
            .foregroundStyle(isEnabled ? FumeColors.background : FumeColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FumeTokens.spacingMedium)
            .background(
                Capsule()
                    .fill(isEnabled ? (configuration.isPressed ? FumeColors.accentDim : FumeColors.accent) : FumeColors.surfaceRaised)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    FumeHaptic.light()
                }
            }
    }
}

// MARK: - Secondary Button Style

struct FumeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: FumeTokens.fontSizeBodySmall, weight: .medium))
            .foregroundStyle(isEnabled ? FumeColors.accent : FumeColors.textSecondary)
            .padding(.horizontal, FumeTokens.spacingLarge)
            .padding(.vertical, FumeTokens.spacingMedium)
            .background(
                Capsule()
                    .stroke(isEnabled ? FumeColors.accent : FumeColors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    FumeHaptic.light()
                }
            }
    }
}

// MARK: - Icon Button Style

struct FumeIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.5))
            .foregroundStyle(configuration.isPressed ? FumeColors.accentDim : FumeColors.accent)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? FumeColors.accent.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    FumeHaptic.light()
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(padding: CGFloat = FumeTokens.spacingLarge, cornerRadius: CGFloat = FumeTokens.cornerRadiusXLarge) -> some View {
        modifier(GlassCard(padding: padding, cornerRadius: cornerRadius))
    }

    func amberGlow(isActive: Bool, cornerRadius: CGFloat = FumeTokens.cornerRadiusXLarge) -> some View {
        modifier(AmberGlow(isActive: isActive, cornerRadius: cornerRadius))
    }
}
