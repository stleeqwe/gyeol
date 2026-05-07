// 결 (Gyeol) — Cards + ChatBubble
// 결_디자인시스템_v1 §2.3.1 (DomainCard), §2.3.2 (CandidateCard), §2.6 (ChatBubble).

import SwiftUI
import GyeolDomain
#if canImport(UIKit)
import UIKit
#endif

// ─── Qualitative label tag (CandidateCard / MatchDetail 헤더) ──

extension QualitativeLabel {
    var gyeolColor: Color {
        switch self {
        case .alignment:  return .gyeolLabelWarm
        case .compromise: return .gyeolLabelNeutral
        case .boundary:   return .gyeolLabelCareful
        }
    }

    var gyeolUppercaseTag: String {
        switch self {
        case .alignment:  return "RESONANCE"
        case .compromise: return "COMPROMISE"
        case .boundary:   return "BOUNDARY"
        }
    }
}

// ─── CandidateCard (매칭 후보 목록 카드) ──────────────────
// 명세 §2.3.2: padding 22, radius 18, 행1 tag uppercase + dot, 행2 headline + 좌측 2pt accent bar,
// divider, 행3 통합 핵심 유형 라벨 caption2 uppercase, 행4 본문 caption1 text.tertiary.

public struct CandidateCard: View {
    public let label: QualitativeLabel
    public let headline: String
    public let coreInterpretation: String

    public init(label: QualitativeLabel, headline: String, coreInterpretation: String) {
        self.label = label
        self.headline = headline
        self.coreInterpretation = coreInterpretation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // tag row
            HStack(spacing: 6) {
                Circle()
                    .fill(label.gyeolColor)
                    .frame(width: 5, height: 5)
                Text(label.gyeolUppercaseTag)
                    .font(.custom("Pretendard-SemiBold", fixedSize: 11))
                    .kerning(11 * 0.15)
                    .foregroundColor(label.gyeolColor)
            }
            .padding(.bottom, 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label.labelKo)

            // headline + left accent bar
            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(Color.gyeolAccentPrimary.opacity(0.5))
                    .frame(width: 2)
                    .padding(.vertical, 6)
                Text(headline)
                    .gyeolStyle(.bodyLarge)
                    .foregroundColor(.gyeolTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 16)

            Divider()
                .background(Color.gyeolDivider)
                .padding(.bottom, 16)

            // core identity label + body
            Text("통합 핵심 유형")
                .font(.custom("Pretendard-Medium", fixedSize: 11))
                .kerning(11 * 0.10)
                .foregroundColor(.gyeolTextTertiary)
                .padding(.bottom, 6)

            Text(coreInterpretation)
                .gyeolStyle(.caption1)
                .foregroundColor(.gyeolTextTertiary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(Color.gyeolBgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: GyeolRadius.xxl, style: .continuous)
                .stroke(Color.gyeolBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.xxl, style: .continuous))
    }
}

// ─── DomainCard (본인 검토 / 후보 펼침 — 영역별) ──────────
// 명세 §2.3.1: padding 18 20, radius 14, expandable.

public struct DomainCard<ExpandedContent: View>: View {
    public let domain: DomainID
    public let summary: String
    public let metaText: String?
    @Binding public var isExpanded: Bool
    public let expandedContent: () -> ExpandedContent

    public init(
        domain: DomainID,
        summary: String,
        metaText: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.domain = domain
        self.summary = summary
        self.metaText = metaText
        self._isExpanded = isExpanded
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolMD) {
            Button(action: { withAnimation(.gyeolMedium) { isExpanded.toggle() } }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("영역 0\(domain.indexNumber)")
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextTertiary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gyeolTextTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    Text(domain.labelKo)
                        .gyeolStyle(.bodyLarge)
                        .foregroundColor(.gyeolTextPrimary)
                    if !summary.isEmpty {
                        Text(summary)
                            .gyeolStyle(.caption1)
                            .foregroundColor(.gyeolTextSecondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isExpanded)
                    }
                    if let meta = metaText {
                        Text(meta)
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolLabelWarm)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.gyeolBgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous)
                .stroke(Color.gyeolBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous))
    }
}

// ─── ChatBubble ───────────────────────────────────────────
// 명세 §2.6: padding 12 16, max 75%, radius 18 + 한쪽 4 (비대칭).
// System message: 가운데, text.tertiary, caption2.

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
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, .gyeolLG)
                Spacer()
            } else if isMine {
                Spacer(minLength: 40)
                Text(message.body)
                    .font(.custom("Pretendard-Regular", fixedSize: 15))
                    .lineSpacing(15 * 0.5)
                    .foregroundColor(.gyeolBgPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gyeolAccentPrimary)
                    .clipShape(BubbleShape(isMine: true))
            } else {
                Text(message.body)
                    .font(.custom("Pretendard-Regular", fixedSize: 15))
                    .lineSpacing(15 * 0.5)
                    .foregroundColor(.gyeolTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gyeolBgSubtle)
                    .clipShape(BubbleShape(isMine: false))
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, .gyeolMD)
        .padding(.vertical, .gyeolXS)
    }
}

private struct BubbleShape: Shape {
    let isMine: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 18
        let small: CGFloat = 4
        let topLeft = big
        let topRight = big
        let bottomLeft: CGFloat = isMine ? big : small
        let bottomRight: CGFloat = isMine ? small : big
        #if canImport(UIKit)
        let bezier = UIBezierPath()
        bezier.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        bezier.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        bezier.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topRight),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
        )
        bezier.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        bezier.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        bezier.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        bezier.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        bezier.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        bezier.addQuadCurve(
            to: CGPoint(x: rect.minX + topLeft, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        bezier.close()
        return Path(bezier.cgPath)
        #else
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: big, height: big))
        return path
        #endif
    }
}

// ─── Deprecated: 기존 MatchCard (CandidateCard로 의미 분리) ──

@available(*, deprecated, renamed: "CandidateCard")
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
        CandidateCard(label: label, headline: headline, coreInterpretation: interpretation)
    }
}
