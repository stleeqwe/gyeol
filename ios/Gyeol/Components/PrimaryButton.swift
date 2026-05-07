// 결 (Gyeol) — Buttons
// 결_디자인시스템_v1 §2.1 — Primary / Link / Stop Recording

import SwiftUI

// ─── Primary Button (CTA — 화면당 1개) ────────────────────
// 명세 §2.1.1: h54, radius 14, accent 채움, scale 0.97 press, opacity 0.35 disabled.

public struct PrimaryButton: View {
    public let title: String
    public let isEnabled: Bool
    public let action: () -> Void

    public init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: { if isEnabled { action() } }) {
            Text(title)
        }
        .buttonStyle(GyeolPrimaryButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal, .gyeolLG)
    }
}

public struct GyeolPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .gyeolStyle(.cta)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isEnabled ? Color.gyeolAccentPrimary : Color.gyeolTextTertiary)
            .foregroundColor(.gyeolBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.gyeolFast, value: configuration.isPressed)
    }
}

// ─── Link Button (시각 위계 최하위) ────────────────────────
// 명세 §2.1.2: text.tertiary 디폴트, hover/press text.secondary, padding 6 0.

public struct LinkButton: View {
    public let title: String
    public let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(GyeolLinkButtonStyle())
    }
}

public struct GyeolLinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Pretendard-Medium", fixedSize: 14))
            .foregroundColor(configuration.isPressed ? .gyeolTextSecondary : .gyeolTextTertiary)
            .padding(.vertical, 6)
            .animation(.gyeolFast, value: configuration.isPressed)
    }
}

// ─── Stop Recording Button (음성 종료 전용) ────────────────
// 명세 §2.1.3: bg.subtle + 1pt border.strong + 좌측 사각 stop 아이콘 + text.primary.

public struct StopRecordingButton: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.gyeolTextPrimary)
                    .frame(width: 14, height: 14)
                Text("녹음 종료")
            }
        }
        .buttonStyle(GyeolStopRecordingButtonStyle())
        .padding(.horizontal, .gyeolLG)
        .accessibilityLabel("녹음 종료")
    }
}

public struct GyeolStopRecordingButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .gyeolStyle(.cta)
            .foregroundColor(.gyeolTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.gyeolBgSubtle)
            .overlay(
                RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous)
                    .stroke(Color.gyeolBorderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.gyeolFast, value: configuration.isPressed)
    }
}

// ─── Deprecated: 기존 SecondaryButton (v1에서 LinkButton으로 의미 변경) ──
// Phase 4에서 모든 사용처 LinkButton으로 마이그레이션 후 제거.

@available(*, deprecated, renamed: "LinkButton", message: "Use LinkButton (text.tertiary 디폴트)")
public struct SecondaryButton: View {
    public let title: String
    public let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        LinkButton(title, action: action)
    }
}
