import XCTest
import SwiftUI
import UIKit
@testable import Mehmmy

final class ThemeTests: XCTestCase {
    private func rgb(_ c: Color, _ style: UIUserInterfaceStyle) -> (Double, Double, Double) {
        let ui = UIColor(c).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func luminance(_ c: (Double, Double, Double)) -> Double {
        func ch(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.0) + 0.7152 * ch(c.1) + 0.0722 * ch(c.2)
    }

    private func contrast(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
        let la = luminance(rgb(a, style)), lb = luminance(rgb(b, style))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testBackgroundFlipsInDarkMode() {
        XCTAssertGreaterThan(luminance(rgb(Palette.cream, .light)), 0.8)
        XCTAssertLessThan(luminance(rgb(Palette.cream, .dark)), 0.05)
        XCTAssertGreaterThan(luminance(rgb(Palette.ink, .dark)), 0.7)
    }

    // ink is both text and border on every surface and accent fill
    func testInkMeetsAAOnEverySurfaceInBothModes() {
        let fills: [(String, Color)] = [
            ("cream", Palette.cream), ("paper", Palette.paper), ("green", Palette.green), ("coral", Palette.coral),
            ("yellow", Palette.yellow), ("sky", Palette.sky), ("mint", Palette.mint), ("peach", Palette.peach),
            ("rose", Palette.rose), ("locked", Palette.locked),
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (name, fill) in fills {
                XCTAssertGreaterThanOrEqual(contrast(Palette.ink, fill, style), 4.5, "\(name) \(style == .dark ? "dark" : "light")")
            }
        }
    }

    func testSecondaryTextIsReadableOnPaper() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(Palette.subtle, Palette.paper, style), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(Palette.muted, Palette.paper, style), 3.0)
        }
    }
}
