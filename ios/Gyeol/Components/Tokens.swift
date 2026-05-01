// 결 (Gyeol) — Design Tokens
// 03-design-system.md §3-§7

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum GyeolColor {
    // Light
    public static let bgPrimary = Color(red: 0.941, green: 0.918, blue: 0.878)        // #F0EAE0
    public static let bgElevated = Color.white
    public static let bgSubtle = Color(red: 0.910, green: 0.886, blue: 0.843)         // #E8E2D7
    public static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)      // #1A1A1A
    public static let textSecondary = Color(red: 0.420, green: 0.404, blue: 0.376)    // #6B6760
    public static let textTertiary = Color(red: 0.612, green: 0.596, blue: 0.565)     // #9C9890
    public static let textDisabled = Color(red: 0.773, green: 0.753, blue: 0.710)     // #C5C0B5
    public static let accent = Color(red: 0.102, green: 0.102, blue: 0.102)
    public static let accentContrast = Color.white
    public static let divider = Color(red: 0.847, green: 0.824, blue: 0.773)          // #D8D2C5
    public static let borderSubtle = divider
    public static let recordingDot = Color(red: 0.769, green: 0.271, blue: 0.271)     // #C44545
    public static let stateAlignment = textPrimary
    public static let stateCompromise = textSecondary
    public static let stateBoundary = Color(red: 0.627, green: 0.353, blue: 0.173)    // #A05A2C
}

public enum GyeolColorDark {
    public static let bgPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)
    public static let bgElevated = Color(red: 0.149, green: 0.149, blue: 0.149)
    public static let bgSubtle = Color(red: 0.184, green: 0.184, blue: 0.184)
    public static let textPrimary = Color(red: 0.941, green: 0.918, blue: 0.878)
    public static let textSecondary = Color(red: 0.659, green: 0.639, blue: 0.604)
    public static let accent = Color(red: 0.941, green: 0.918, blue: 0.878)
    public static let accentContrast = Color(red: 0.102, green: 0.102, blue: 0.102)
    public static let recordingDot = Color(red: 0.878, green: 0.376, blue: 0.376)
}

// Adaptive colors — light/dark는 system colorScheme로 자동 분기.
// 운영 단계에서 Asset Catalog로 옮길 수 있으나 SPM resources 의존성을 줄이기 위해 inline 정의.

public extension Color {
    static let gyBg = Color(light: GyeolColor.bgPrimary, dark: GyeolColorDark.bgPrimary)
    static let gyBgElevated = Color(light: GyeolColor.bgElevated, dark: GyeolColorDark.bgElevated)
    static let gyBgSubtle = Color(light: GyeolColor.bgSubtle, dark: GyeolColorDark.bgSubtle)
    static let gyText = Color(light: GyeolColor.textPrimary, dark: GyeolColorDark.textPrimary)
    static let gyTextSecondary = Color(light: GyeolColor.textSecondary, dark: GyeolColorDark.textSecondary)
    static let gyTextTertiary = Color(light: GyeolColor.textTertiary, dark: GyeolColor.textTertiary)
    static let gyTextDisabled = Color(light: GyeolColor.textDisabled, dark: GyeolColor.textDisabled)
    static let gyAccent = Color(light: GyeolColor.accent, dark: GyeolColorDark.accent)
    static let gyAccentContrast = Color(light: GyeolColor.accentContrast, dark: GyeolColorDark.accentContrast)
    static let gyDivider = Color(light: GyeolColor.divider, dark: GyeolColor.divider)
    static let gyRecording = Color(light: GyeolColor.recordingDot, dark: GyeolColorDark.recordingDot)
    static let gyBoundary = Color(light: GyeolColor.stateBoundary, dark: GyeolColor.stateBoundary)

    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}

public enum GySpace {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let section: CGFloat = 64
}

public enum GyRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 24
    public static let cta: CGFloat = 12
}

public enum GyType {
    public static func brand(_ size: CGFloat = 80) -> Font { .system(size: size, weight: .heavy, design: .serif) }
    public static let subBrand: Font = .system(size: 11, weight: .medium, design: .default)
    public static let headlineLG: Font = .system(size: 22, weight: .semibold)
    public static let headlineMD: Font = .system(size: 18, weight: .semibold)
    public static let headlineSM: Font = .system(size: 16, weight: .semibold)
    public static let bodyLG: Font = .system(size: 15, weight: .regular)
    public static let bodyMD: Font = .system(size: 14, weight: .regular)
    public static let bodySM: Font = .system(size: 13.5, weight: .regular)
    public static let labelMD: Font = .system(size: 13, weight: .medium)
    public static let caption: Font = .system(size: 11, weight: .medium)
    public static let cta: Font = .system(size: 16, weight: .semibold)
    public static let mono: Font = .system(size: 13, weight: .regular, design: .monospaced)
}

public enum GyMotion {
    public static let swift: Animation = .easeInOut(duration: 0.2)
    public static let standard: Animation = .easeInOut(duration: 0.3)
    public static let calm: Animation = .easeInOut(duration: 0.45)
    public static let pulse: Animation = .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    public static let recordingDot: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    public static let waveform: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
}

public var gyTopBarTrailing: ToolbarItemPlacement {
    #if os(iOS)
    .topBarTrailing
    #else
    .automatic
    #endif
}

public extension View {
    @ViewBuilder
    func gyNavigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func gyNavigationBarHidden() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
