import SwiftUI

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xE85D4A
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum DragonTheme {
    static let ink = Color(red: 0.12, green: 0.10, blue: 0.16)
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.87)
    static let coral = Color(red: 0.87, green: 0.30, blue: 0.24)
    static let coralDark = Color(red: 0.57, green: 0.15, blue: 0.14)
    static let mint = Color(red: 0.45, green: 0.73, blue: 0.58)
    static let sky = Color(red: 0.70, green: 0.86, blue: 0.87)
    static let gold = Color(red: 0.94, green: 0.68, blue: 0.24)

    static let card = LinearGradient(colors: [Color.white.opacity(0.96), Color.white.opacity(0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    func dragonCard() -> some View {
        self.padding(18)
            .background(DragonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: DragonTheme.ink.opacity(0.08), radius: 18, y: 8)
    }
}
