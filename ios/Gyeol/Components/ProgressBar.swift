// 결 (Gyeol) — Progress + Modal + ChoiceChip + LoadingDots
// 결_디자인시스템_v1 §2.4.1, §2.4.2, §2.5.

import SwiftUI

// ─── Progress Bar ─────────────────────────────────────────
// 명세 §2.4.1: h 1.5pt, divider bg, accent.primary fill, spring 0.5s.

public struct GyProgressBar: View {
    public let current: Int
    public let total: Int

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        let progress = Double(current) / Double(max(1, total))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.gyeolDivider).frame(height: 1.5)
                Rectangle().fill(Color.gyeolAccentPrimary)
                    .frame(width: geo.size.width * progress, height: 1.5)
                    .animation(.gyeolSlow, value: progress)
            }
            .clipShape(Capsule())
        }
        .frame(height: 1.5)
    }
}

// ─── Loading Dots ─────────────────────────────────────────
// 명세 §2.4.2: 6×6 점 3개, gap 8, opacity 0.3↔1.0 + scale 0.8↔1.0, 1.4s ease infinite, stagger 0.2s.

public struct LoadingDots: View {
    @State private var animating: Bool = false

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.gyeolTextSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 1.0 : 0.3)
                    .scaleEffect(animating ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("불러오는 중")
    }
}

// ─── Modal ────────────────────────────────────────────────
// 명세 §2.5.1: w 320, radius 18, padding 24, title 16 SemiBold, body 13.5 Regular text.secondary.

public struct GyModal<Content: View>: View {
    public let title: String
    public let primaryLabel: String
    public let secondaryLabel: String
    public let onPrimary: () -> Void
    public let onSecondary: () -> Void
    public let content: () -> Content

    public init(
        title: String,
        primaryLabel: String,
        secondaryLabel: String = "취소",
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolSM) {
            Text(title)
                .font(.custom("Pretendard-SemiBold", fixedSize: 16))
                .foregroundColor(.gyeolTextPrimary)
            content()
                .font(.custom("Pretendard-Regular", fixedSize: 13.5))
                .foregroundColor(.gyeolTextSecondary)
                .lineSpacing(13.5 * 0.55)
            Divider().background(Color.gyeolDivider).padding(.vertical, .gyeolXS)
            HStack(spacing: 0) {
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(.custom("Pretendard-Medium", fixedSize: 15))
                        .foregroundColor(.gyeolTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                Divider().background(Color.gyeolDivider).frame(width: 1, height: 24)
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.custom("Pretendard-SemiBold", fixedSize: 15))
                        .foregroundColor(.gyeolAccentPrimary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.gyeolLG)
        .frame(width: 320)
        .background(Color.gyeolBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
    }
}

// ─── ChoiceChip ───────────────────────────────────────────

public struct ChoiceChip: View {
    public let label: String
    public let isSelected: Bool
    public let onTap: () -> Void

    public init(label: String, isSelected: Bool, onTap: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            GyeolHaptic.selection()
            onTap()
        }) {
            HStack(spacing: .gyeolSM) {
                Circle()
                    .stroke(isSelected ? Color.gyeolAccentPrimary : Color.gyeolBorder, lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color.gyeolAccentPrimary)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                Text(label)
                    .gyeolStyle(.body)
                    .foregroundColor(.gyeolTextPrimary)
                Spacer()
            }
            .padding(.vertical, .gyeolSM)
            .padding(.horizontal, .gyeolMD)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: GyeolRadius.md)
                    .stroke(isSelected ? Color.gyeolAccentPrimary : Color.gyeolBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
