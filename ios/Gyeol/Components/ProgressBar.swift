// 결 (Gyeol) — Progress + Modal + ChoiceChip

import SwiftUI

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
                Rectangle().fill(Color.gyDivider).frame(height: 2)
                Rectangle().fill(Color.gyText).frame(width: geo.size.width * progress, height: 2)
                    .animation(GyMotion.standard, value: progress)
            }
        }
        .frame(height: 2)
    }
}

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
        VStack(alignment: .leading, spacing: GySpace.sm) {
            Text(title).font(GyType.headlineSM).foregroundColor(.gyText)
            content()
                .font(GyType.bodySM)
                .foregroundColor(.gyTextSecondary)
                .lineSpacing(4)
            Divider().background(Color.gyDivider).padding(.vertical, GySpace.xs)
            HStack(spacing: GySpace.lg) {
                Spacer()
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gyTextSecondary)
                }.buttonStyle(.plain)
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gyAccent)
                }.buttonStyle(.plain)
            }
        }
        .padding(GySpace.lg)
        .frame(width: 320)
        .background(Color.gyBgElevated)
        .clipShape(RoundedRectangle(cornerRadius: GyRadius.lg, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 4)
    }
}

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
        Button(action: onTap) {
            HStack(spacing: GySpace.sm) {
                Circle()
                    .stroke(isSelected ? Color.gyText : Color.gyDivider, lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color.gyText)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                Text(label)
                    .font(GyType.bodyMD)
                    .foregroundColor(.gyText)
                Spacer()
            }
            .padding(.vertical, GySpace.sm)
            .padding(.horizontal, GySpace.md)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: GyRadius.md)
                    .stroke(isSelected ? Color.gyText : Color.gyDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
