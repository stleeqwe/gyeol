// 결 (Gyeol) — MatchCard + ChatBubble

import SwiftUI
import GyeolCore
import GyeolDomain
#if canImport(UIKit)
import UIKit
#endif

public struct MatchCard: View {
    public let label: QualitativeLabel
    public let headline: String
    public let coreLabel: String
    public let interpretation: String

    public init(label: QualitativeLabel, headline: String, coreLabel: String, interpretation: String) {
        self.label = label
        self.headline = headline
        self.coreLabel = coreLabel
        self.interpretation = interpretation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GySpace.md) {
            HStack(spacing: GySpace.xs) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(label.labelKo)
                    .font(GyType.labelMD)
                    .foregroundColor(.gyTextSecondary)
            }
            Text(headline)
                .font(GyType.headlineMD)
                .foregroundColor(.gyText)
                .fixedSize(horizontal: false, vertical: true)
            Divider().background(Color.gyDivider)
            VStack(alignment: .leading, spacing: GySpace.xs) {
                Text("통합 핵심 유형")
                    .font(GyType.caption)
                    .foregroundColor(.gyTextTertiary)
                Text(interpretation)
                    .font(GyType.bodyMD)
                    .foregroundColor(.gyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GySpace.lg)
        .background(Color.gyBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: GyRadius.xl, style: .continuous))
    }

    private var dotColor: Color {
        switch label {
        case .alignment: return .gyText
        case .compromise: return .gyTextSecondary
        case .boundary: return .gyBoundary
        }
    }
}

public struct ChatBubble: View {
    public let message: ChatMessage
    public let isMine: Bool

    public init(message: ChatMessage, isMine: Bool) {
        self.message = message
        self.isMine = isMine
    }

    public var body: some View {
        HStack {
            if message.isSystem {
                Spacer()
                Text(message.body)
                    .font(GyType.bodySM)
                    .foregroundColor(.gyTextSecondary)
                Spacer()
            } else if isMine {
                Spacer(minLength: 40)
                Text(message.body)
                    .font(GyType.bodyLG)
                    .foregroundColor(.gyAccentContrast)
                    .padding(.horizontal, GySpace.md)
                    .padding(.vertical, GySpace.sm)
                    .background(Color.gyAccent)
                    .clipShape(BubbleShape(isMine: true))
            } else {
                Text(message.body)
                    .font(GyType.bodyLG)
                    .foregroundColor(.gyText)
                    .padding(.horizontal, GySpace.md)
                    .padding(.vertical, GySpace.sm)
                    .background(Color.gyBgSubtle)
                    .clipShape(BubbleShape(isMine: false))
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, GySpace.md)
        .padding(.vertical, GySpace.xs)
    }
}

private struct BubbleShape: Shape {
    let isMine: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let smallR: CGFloat = 4
        return Path { p in
            #if canImport(UIKit)
            let path = UIBezierPath(roundedRect: rect,
                                    byRoundingCorners: isMine ?
                                        [.topLeft, .topRight, .bottomLeft] :
                                        [.topLeft, .topRight, .bottomRight],
                                    cornerRadii: CGSize(width: r, height: r))
            p.addPath(Path(path.cgPath))
            _ = smallR  // 본 단순화에서는 코너별 차등 미적용 (운영 단계 보강)
            #else
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
            _ = smallR
            #endif
        }
    }
}
