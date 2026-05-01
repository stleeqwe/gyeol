// 결 (Gyeol) — PrimaryButton / SecondaryButton
// 03-design-system §8.1, §8.2

import SwiftUI

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
                .font(GyType.cta)
                .foregroundColor(.gyAccentContrast)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Color.gyAccent : Color.gyTextDisabled)
                .clipShape(RoundedRectangle(cornerRadius: GyRadius.cta, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, GySpace.lg)
    }
}

public struct SecondaryButton: View {
    public let title: String
    public let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(GyType.labelMD)
                .foregroundColor(.gyTextSecondary)
                .padding(.horizontal, GySpace.sm)
                .padding(.vertical, GySpace.xs)
        }
        .buttonStyle(.plain)
    }
}
