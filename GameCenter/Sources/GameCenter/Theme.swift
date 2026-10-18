import SwiftUI

/// 统一深色「游戏启动器」设计令牌。
/// 与 Windows Electron 端共享同一套配色，保证两端视觉一致。
extension Color {
    /// 从十六进制字符串（#RRGGBB 或 RRGGBB）构造颜色。
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    // 背景层
    static let gcBg = Color(hex: "#0b0d12")
    static let gcSide = Color(hex: "#11141c")
    static let gcCard = Color(hex: "#181c28")
    static let gcCardHover = Color(hex: "#1f2533")
    static let gcLine = Color(hex: "#262c3a")

    // 文字
    static let gcText = Color(hex: "#eef1f8")
    static let gcMuted = Color(hex: "#8b93a7")

    // 强调色
    static let gcAccent = Color(hex: "#7c5cff")
    static let gcAccent2 = Color(hex: "#22d3ee")
    static let gcGreen = Color(hex: "#43d17a")
    static let gcRed = Color(hex: "#ff5d5d")
}
