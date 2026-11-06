import SwiftUI
import UIKit

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

extension Color {
    // light/dark pair resolved by the system trait
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

enum Palette {
    static let cream = Color(light: 0xFFF8EC, dark: 0x14130F)
    static let ink = Color(light: 0x161512, dark: 0xF4EEE1)
    static let paper = Color(light: 0xFFFFFF, dark: 0x221F1A)
    static let green = Color(light: 0x2FBF71, dark: 0x1C6B43)
    static let coral = Color(light: 0xFF6B4A, dark: 0x9E3622)
    static let yellow = Color(light: 0xFFD23F, dark: 0x7A5E00)
    static let sky = Color(light: 0x7DD3FC, dark: 0x1D5876)
    static let mint = Color(light: 0x86EFAC, dark: 0x1F6140)
    static let peach = Color(light: 0xFED7AA, dark: 0x7A4A26)
    static let rose = Color(light: 0xFDA4AF, dark: 0x8A3343)
    static let muted = Color(light: 0x9A8F7A, dark: 0x9C9383)
    static let subtle = Color(light: 0x6B6557, dark: 0xC9C0AE)
    static let faint = Color(light: 0xC2B8A3, dark: 0x6E675A)
    static let dash = Color(light: 0xCABF9F, dark: 0x5E574B)
    static let locked = Color(light: 0xF3EFE2, dark: 0x2B2822)
    static let disabled = Color(light: 0xE6DFCA, dark: 0x3A362E)
    static let disabledText = Color(light: 0xA89E88, dark: 0x8A8172)
    static let deepGreen = Color(light: 0x0F8A4C, dark: 0x5FD99A)
    static let forest = Color(light: 0x0F5132, dark: 0x9BE7BF)
    static let burnt = Color(light: 0xC2410C, dark: 0xFF9A6B)
    static let navy = Color(light: 0x0C4A6E, dark: 0xBAE6FD)

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
