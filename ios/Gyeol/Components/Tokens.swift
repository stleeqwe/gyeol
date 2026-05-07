// 결 (Gyeol) — Design Tokens
// 결_디자인시스템_v1 §1 (Color / Typography / Space / Radius / Animation / Haptic).
// Asset Catalog 기반 컬러 + Pretendard custom font + 8단계 시맨틱 위계.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ─── Color ────────────────────────────────────────────────
// 결_디자인시스템_v1 §1.1.1 / §1.1.2
// Light/Dark 자동 분기는 Asset Catalog (Tokens.xcassets) 처리.

public extension Color {
    // Background
    static let gyeolBgPage     = Color("BgPage")
    static let gyeolBgPrimary  = Color("BgPrimary")
    static let gyeolBgElevated = Color("BgElevated")
    static let gyeolBgSubtle   = Color("BgSubtle")

    // Text
    static let gyeolTextPrimary   = Color("TextPrimary")
    static let gyeolTextSecondary = Color("TextSecondary")
    static let gyeolTextTertiary  = Color("TextTertiary")

    // Accent
    static let gyeolAccentPrimary = Color("AccentPrimary")
    static let gyeolAccentSoft    = Color("AccentSoft")

    // Border / divider
    static let gyeolBorder       = Color("Border")
    static let gyeolBorderStrong = Color("BorderStrong")
    static let gyeolDivider      = Color("Divider")

    // Qualitative labels (matching tone)
    static let gyeolLabelWarm    = Color("LabelWarm")
    static let gyeolLabelNeutral = Color("LabelNeutral")
    static let gyeolLabelCareful = Color("LabelCareful")

    // State
    static let gyeolStateRecording = Color("StateRecording")
}

// ─── Spacing (4pt base, 8 steps) ──────────────────────────
// 결_디자인시스템_v1 §1.3

public extension CGFloat {
    static let gyeolXS:  CGFloat = 4
    static let gyeolSM:  CGFloat = 8
    static let gyeolMD:  CGFloat = 16
    static let gyeolLG:  CGFloat = 24
    static let gyeolXL:  CGFloat = 32
    static let gyeol2XL: CGFloat = 48
    static let gyeol3XL: CGFloat = 64
    static let gyeol4XL: CGFloat = 96
}

// ─── Radius ───────────────────────────────────────────────
// 결_디자인시스템_v1 §1.4

public enum GyeolRadius {
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 14   // CTA 버튼
    public static let xl:  CGFloat = 16
    public static let xxl: CGFloat = 18
    public static let xxxl: CGFloat = 24
}

// ─── Typography (8단계 시맨틱 위계) ────────────────────────
// 결_디자인시스템_v1 §1.2
// Pretendard 미적재 시 Font.custom은 system font fallback (UI 깨지지 않음).

public extension Font {
    static let gyeolDisplay   = Font.custom("Pretendard-SemiBold", fixedSize: 28)
    static let gyeolTitle1    = Font.custom("Pretendard-SemiBold", fixedSize: 24)
    static let gyeolTitle2    = Font.custom("Pretendard-SemiBold", fixedSize: 22)
    static let gyeolTitle3    = Font.custom("Pretendard-SemiBold", fixedSize: 20)
    static let gyeolBodyLarge = Font.custom("Pretendard-Medium",   fixedSize: 18)
    static let gyeolBody      = Font.custom("Pretendard-Regular",  fixedSize: 17)
    static let gyeolCaption1  = Font.custom("Pretendard-Regular",  fixedSize: 15)
    static let gyeolCaption2  = Font.custom("Pretendard-Regular",  fixedSize: 13)
    static let gyeolCTA       = Font.custom("Pretendard-SemiBold", fixedSize: 16)
    static let gyeolMonoSmall = Font.system(size: 12.5, weight: .regular, design: .monospaced)
}

/// line-height + letter-spacing 통합 적용 헬퍼.
/// 사용: `Text("…").gyeolStyle(.body)`
public struct GyeolTextStyle: ViewModifier {
    public enum Variant {
        case display, title1, title2, title3, bodyLarge, body, caption1, caption2, cta

        var font: Font {
            switch self {
            case .display:   return .gyeolDisplay
            case .title1:    return .gyeolTitle1
            case .title2:    return .gyeolTitle2
            case .title3:    return .gyeolTitle3
            case .bodyLarge: return .gyeolBodyLarge
            case .body:      return .gyeolBody
            case .caption1:  return .gyeolCaption1
            case .caption2:  return .gyeolCaption2
            case .cta:       return .gyeolCTA
            }
        }

        // line-height multiplier (vs font size)
        var lineHeight: CGFloat {
            switch self {
            case .display:   return 1.30
            case .title1:    return 1.40
            case .title2:    return 1.45
            case .title3:    return 1.40
            case .bodyLarge: return 1.50
            case .body:      return 1.70
            case .caption1:  return 1.55
            case .caption2:  return 1.40
            case .cta:       return 1.30
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .display:   return 28
            case .title1:    return 24
            case .title2:    return 22
            case .title3:    return 20
            case .bodyLarge: return 18
            case .body:      return 17
            case .caption1:  return 15
            case .caption2:  return 13
            case .cta:       return 16
            }
        }

        var kerning: CGFloat {
            // letter-spacing em → pt
            let em: CGFloat
            switch self {
            case .display:   em = -0.04
            case .title1, .title2: em = -0.025
            case .title3:    em = -0.015
            case .bodyLarge: em = -0.015
            case .body:      em = -0.005
            case .caption1, .caption2: em = 0.005
            case .cta:       em = -0.01
            }
            return em * fontSize
        }
    }

    public let variant: Variant

    public func body(content: Content) -> some View {
        content
            .font(variant.font)
            .lineSpacing((variant.lineHeight - 1.0) * variant.fontSize)
            .kerning(variant.kerning)
    }
}

public extension View {
    func gyeolStyle(_ variant: GyeolTextStyle.Variant) -> some View {
        modifier(GyeolTextStyle(variant: variant))
    }
}

// ─── Animation ────────────────────────────────────────────
// 결_디자인시스템_v1 §1.6

public extension Animation {
    static let gyeolFast   = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let gyeolMedium = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let gyeolSlow   = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let gyeolFade   = Animation.easeInOut(duration: 0.3)
    static let gyeolFadeUI = Animation.easeOut(duration: 0.3)
}

// ─── Toolbar placement helpers ────────────────────────────

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

// ─── Deprecated aliases (Phase 1 — Phase 4에서 일괄 마이그레이션) ──
// 기존 코드(gy*, GySpace, GyType, GyMotion, GyRadius)가 깨지지 않도록 신규 토큰을 가리키게 함.
// 새 코드는 위쪽의 gyeol* 토큰 사용 권장.

@available(*, deprecated, message: "Use Color.gyeolBgPrimary")
public extension Color {
    static let gyBg            = Color.gyeolBgPrimary
    static let gyBgElevated    = Color.gyeolBgElevated
    static let gyBgSubtle      = Color.gyeolBgSubtle
    static let gyText          = Color.gyeolTextPrimary
    static let gyTextSecondary = Color.gyeolTextSecondary
    static let gyTextTertiary  = Color.gyeolTextTertiary
    static let gyTextDisabled  = Color.gyeolTextTertiary    // 신규는 별도 disabled 없음 — opacity 35%로 처리
    static let gyAccent        = Color.gyeolAccentPrimary
    static let gyAccentContrast = Color.gyeolBgPrimary       // 라이트 흰색, 다크 차콜
    static let gyDivider       = Color.gyeolDivider
    static let gyRecording     = Color.gyeolStateRecording
    static let gyBoundary      = Color.gyeolLabelCareful     // 경계 확인 → label.careful
}

@available(*, deprecated, message: "Use CGFloat.gyeol* spacing tokens")
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

@available(*, deprecated, message: "Use GyeolRadius")
public enum GyRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 24
    public static let cta: CGFloat = 14   // 신규 명세: 14pt
}

@available(*, deprecated, message: "Use Font.gyeol* + .gyeolStyle(...)")
public enum GyType {
    public static func brand(_ size: CGFloat = 80) -> Font { .system(size: size, weight: .heavy, design: .serif) }
    public static let subBrand: Font = .system(size: 11, weight: .medium, design: .default)
    public static let headlineLG: Font = .gyeolTitle1
    public static let headlineMD: Font = .gyeolBodyLarge
    public static let headlineSM: Font = .gyeolCTA
    public static let bodyLG: Font = .gyeolCaption1
    public static let bodyMD: Font = .gyeolBody
    public static let bodySM: Font = .gyeolCaption2
    public static let labelMD: Font = .gyeolCaption2
    public static let caption: Font = .gyeolCaption2
    public static let cta: Font = .gyeolCTA
    public static let mono: Font = .gyeolMonoSmall
}

@available(*, deprecated, message: "Use Animation.gyeol*")
public enum GyMotion {
    public static let swift: Animation = .gyeolFast
    public static let standard: Animation = .gyeolMedium
    public static let calm: Animation = .gyeolSlow
    public static let pulse: Animation = .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    public static let recordingDot: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    public static let waveform: Animation = .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
}
