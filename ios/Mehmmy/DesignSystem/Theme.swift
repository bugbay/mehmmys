import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Palette {
    static let cream = Color(hex: 0xFFF8EC)
    static let ink = Color(hex: 0x161512)
    static let paper = Color.white
    static let green = Color(hex: 0x2FBF71)
    static let coral = Color(hex: 0xFF6B4A)
    static let yellow = Color(hex: 0xFFD23F)
    static let sky = Color(hex: 0x7DD3FC)
    static let mint = Color(hex: 0x86EFAC)
    static let peach = Color(hex: 0xFED7AA)
    static let rose = Color(hex: 0xFDA4AF)
    static let muted = Color(hex: 0x9A8F7A)
    static let subtle = Color(hex: 0x6B6557)
    static let faint = Color(hex: 0xC2B8A3)
    static let dash = Color(hex: 0xCABF9F)
    static let locked = Color(hex: 0xF3EFE2)
    static let disabled = Color(hex: 0xE6DFCA)
    static let disabledText = Color(hex: 0xA89E88)
    static let deepGreen = Color(hex: 0x0F8A4C)
    static let forest = Color(hex: 0x0F5132)
    static let burnt = Color(hex: 0xC2410C)
    static let navy = Color(hex: 0x0C4A6E)

    static let avatarColors: [Color] = [
        0xFDBA74, 0xC4B5FD, 0xF9A8D4, 0x7DD3FC, 0xFCD34D, 0x86EFAC,
        0xFDE68A, 0xFCA5A5, 0xA7F3D0, 0xFBCFE8, 0xBFDBFE, 0xDDD6FE,
    ].map { Color(hex: $0) }
}

enum Typo {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .custom("Bricolage Grotesque", size: size, relativeTo: .title).weight(weight)
    }

    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom("Space Grotesk", size: size, relativeTo: .body).weight(weight)
    }
}

enum Metrics {
    static let border: CGFloat = 2.5
    static let gutter: CGFloat = 18
}
