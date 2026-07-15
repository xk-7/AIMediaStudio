import SwiftUI

/// Centralised colours, gradients and reusable view styling for a modern,
/// polished studio look.
enum Theme {
    static let accent = Color(red: 0.49, green: 0.36, blue: 0.98)          // violet
    static let accentSecondary = Color(red: 0.28, green: 0.62, blue: 0.99) // blue
    static let pink = Color(red: 0.95, green: 0.42, blue: 0.78)
    static let teal = Color(red: 0.30, green: 0.82, blue: 0.80)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var vividGradient: LinearGradient {
        LinearGradient(colors: [pink, accent, accentSecondary],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// A soft, appearance-aware hairline border used on glass cards.
    static var hairline: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Aurora-style ambient background used behind the main content area.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            GeometryReader { geo in
                ZStack {
                    blob(Theme.accent, 0.16, 540)
                        .offset(x: -geo.size.width * 0.30, y: -geo.size.height * 0.38)
                    blob(Theme.accentSecondary, 0.14, 600)
                        .offset(x: geo.size.width * 0.42, y: geo.size.height * 0.08)
                    blob(Theme.pink, 0.12, 460)
                        .offset(x: geo.size.width * 0.12, y: geo.size.height * 0.48)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, _ opacity: Double, _ size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 150)
    }
}

/// A rounded frosted-glass "card" container used throughout the UI.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// A prominent gradient call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if enabled {
                        Theme.brandGradient
                    } else {
                        Color.gray.opacity(0.4)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: enabled ? Theme.accent.opacity(configuration.isPressed ? 0.15 : 0.35) : .clear,
                    radius: 10, y: 5)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A large title rendered with the brand gradient.
struct GradientTitle: View {
    let text: String
    var size: CGFloat = 26
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Theme.brandGradient)
    }
}
