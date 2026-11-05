import SwiftUI

// card with ink border and hard offset shadow
struct Brutal: ViewModifier {
    var fill: Color = Palette.paper
    var radius: CGFloat = 14
    var shadow: CGFloat = 2
    var border: CGFloat = Metrics.border

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.ink, lineWidth: border))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ink)
                    .offset(x: shadow, y: shadow)
            )
    }
}

extension View {
    func brutal(_ fill: Color = Palette.paper, radius: CGFloat = 14, shadow: CGFloat = 2, border: CGFloat = Metrics.border) -> some View {
        modifier(Brutal(fill: fill, radius: radius, shadow: shadow, border: border))
    }
}

struct BrutalButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = Palette.ink
    var radius: CGFloat = 16
    var shadow: CGFloat = 4
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        configuration.label
            .font(Typo.display(16))
            .foregroundStyle(enabled ? foreground : Palette.disabledText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(enabled ? fill : Palette.disabled))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(enabled ? Palette.ink : Palette.faint, lineWidth: Metrics.border)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(enabled ? Palette.ink : .clear)
                    .offset(x: shadow, y: shadow)
            )
            .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    var fill: Color = Palette.green
    var foreground: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.display(12))
            .foregroundStyle(foreground)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: Metrics.border))
            .background(Capsule().fill(Palette.ink).offset(x: 2, y: 2))
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
    }
}

struct Avatar: View {
    let emoji: String
    let color: Color
    var size: CGFloat = 40
    var selected = false
    var glow: Color = Palette.green

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: selected ? 3 : 2))
            .background(Circle().fill(selected ? glow : .clear).offset(x: 3, y: 3))
            .accessibilityHidden(true)
    }
}

struct Chip: View {
    let label: String
    var selected = false
    var color: Color = Palette.yellow

    var body: some View {
        Text(label)
            .font(Typo.body(13, selected ? .bold : .semibold))
            .lineLimit(1)
            .foregroundStyle(selected ? Palette.ink : Palette.subtle)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Capsule().fill(selected ? color : Palette.cream))
            .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: selected ? Metrics.border : 2))
            .background(Capsule().fill(selected ? Palette.ink : .clear).offset(x: 2, y: 2))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DashedChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typo.body(13, .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Capsule().fill(Palette.cream))
            .overlay(Capsule().strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
    }
}

struct ScreenTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Typo.display(27)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(Typo.body(13, .medium)).foregroundStyle(Palette.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Typo.display(13))
            .tracking(0.4)
            .foregroundStyle(Palette.ink)
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text).font(Typo.body(11, .bold)).foregroundStyle(Palette.muted)
    }
}

struct IconTile: View {
    let icon: String
    var fill: Color = Palette.cream
    var size: CGFloat = 42

    var body: some View {
        Text(icon)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

struct BrutalField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.faint))
            .font(Typo.body(15, .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.ink, lineWidth: Metrics.border))
    }
}

struct RouteLine: View {
    var body: some View {
        HStack(spacing: 8) {
            dot(Palette.green)
            dashes
            Text("🚗").font(.system(size: 15))
            dashes
            dot(Palette.coral)
        }
        .accessibilityHidden(true)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 13, height: 13).overlay(Circle().strokeBorder(Palette.ink, lineWidth: Metrics.border))
    }

    private var dashes: some View {
        Line().stroke(Palette.dash, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])).frame(height: 2.5)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            IconTile(icon: toast.emoji)
            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title).font(Typo.display(17)).foregroundStyle(Palette.ink)
                Text(toast.subtitle).font(Typo.body(12)).foregroundStyle(Palette.forest).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .brutal(Palette.mint, radius: 16, shadow: 4)
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement(children: .combine)
    }
}
