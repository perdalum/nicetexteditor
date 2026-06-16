import AppKit

enum EditorBackgroundColor: String, CaseIterable {
    case system
    case cream
    case mint
    case sky
    case lavender
    case rose
    case slate
    case black
    case white

    var displayName: String {
        switch self {
        case .system: "System"
        case .cream: "Cream"
        case .mint: "Mint"
        case .sky: "Sky"
        case .lavender: "Lavender"
        case .rose: "Rose"
        case .slate: "Slate"
        case .black: "Black"
        case .white: "White"
        }
    }

    var color: NSColor {
        switch self {
        case .system:
            NSColor.textBackgroundColor
        case .cream:
            dynamicColor(light: rgb(1.00, 0.97, 0.86), dark: rgb(0.18, 0.15, 0.10))
        case .mint:
            dynamicColor(light: rgb(0.88, 0.98, 0.91), dark: rgb(0.09, 0.18, 0.13))
        case .sky:
            dynamicColor(light: rgb(0.88, 0.95, 1.00), dark: rgb(0.09, 0.14, 0.20))
        case .lavender:
            dynamicColor(light: rgb(0.94, 0.91, 1.00), dark: rgb(0.15, 0.12, 0.22))
        case .rose:
            dynamicColor(light: rgb(1.00, 0.91, 0.93), dark: rgb(0.21, 0.11, 0.13))
        case .slate:
            dynamicColor(light: rgb(0.92, 0.95, 0.97), dark: rgb(0.11, 0.13, 0.16))
        case .black:
            NSColor.black
        case .white:
            NSColor.white
        }
    }
}

enum EditorForegroundColor: String, CaseIterable {
    case system
    case ink
    case softBlack
    case blue
    case green
    case amber
    case purple
    case sepia

    var displayName: String {
        switch self {
        case .system: "System"
        case .ink: "Ink"
        case .softBlack: "Soft Black"
        case .blue: "Blue"
        case .green: "Green"
        case .amber: "Amber"
        case .purple: "Purple"
        case .sepia: "Sepia"
        }
    }

    var color: NSColor {
        switch self {
        case .system:
            NSColor.textColor
        case .ink:
            dynamicColor(light: rgb(0.05, 0.05, 0.05), dark: rgb(0.94, 0.94, 0.90))
        case .softBlack:
            dynamicColor(light: rgb(0.22, 0.22, 0.22), dark: rgb(0.78, 0.78, 0.78))
        case .blue:
            dynamicColor(light: rgb(0.05, 0.23, 0.55), dark: rgb(0.55, 0.75, 1.00))
        case .green:
            dynamicColor(light: rgb(0.00, 0.36, 0.16), dark: rgb(0.28, 1.00, 0.43))
        case .amber:
            dynamicColor(light: rgb(0.55, 0.28, 0.00), dark: rgb(1.00, 0.74, 0.22))
        case .purple:
            dynamicColor(light: rgb(0.30, 0.14, 0.55), dark: rgb(0.78, 0.62, 1.00))
        case .sepia:
            dynamicColor(light: rgb(0.36, 0.22, 0.10), dark: rgb(0.86, 0.72, 0.52))
        }
    }
}

private func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua ? dark : light
    }
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
}
