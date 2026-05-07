// 결 (Gyeol) — Custom Top Bar
// 결_디자인시스템_v1 §2.7 — h 48pt, 좌우 패딩 화면 24 안에 정렬, 입력 focus 시 페이드.

import SwiftUI

/// NavigationStack 기본 toolbar 대신 사용하는 화면 상단 바.
/// - 입력 focus 상태(`isInputActive`)일 때 opacity 0.4로 페이드.
/// - 좌측: 뒤로 가기 / X (옵션). 우측: 액션 (옵션).
public struct GyeolTopBar<TrailingContent: View>: View {
    public let onBack: (() -> Void)?
    public let centerLabel: String?
    public let trailing: () -> TrailingContent
    public let isInputActive: Bool

    public init(
        onBack: (() -> Void)? = nil,
        centerLabel: String? = nil,
        isInputActive: Bool = false,
        @ViewBuilder trailing: @escaping () -> TrailingContent
    ) {
        self.onBack = onBack
        self.centerLabel = centerLabel
        self.isInputActive = isInputActive
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .center, spacing: .gyeolMD) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gyeolTextPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로 가기")
            } else {
                Spacer().frame(width: 28)
            }
            Spacer()
            if let centerLabel {
                Text(centerLabel)
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
            }
            Spacer()
            trailing()
                .frame(minWidth: 28, alignment: .trailing)
        }
        .frame(height: 48)
        .padding(.horizontal, .gyeolLG)
        .opacity(isInputActive ? 0.4 : 1.0)
        .animation(.gyeolFadeUI, value: isInputActive)
    }
}

public extension GyeolTopBar where TrailingContent == EmptyView {
    init(onBack: (() -> Void)? = nil, centerLabel: String? = nil, isInputActive: Bool = false) {
        self.init(onBack: onBack, centerLabel: centerLabel, isInputActive: isInputActive) { EmptyView() }
    }
}
