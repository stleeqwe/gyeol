// 결 (Gyeol) — 잠시 멈추기 toolbar modifier
// 03-design-system §8.2 (SecondaryButton tone)

import SwiftUI

public extension View {
    /// Top-trailing 텍스트 버튼. 모든 인터뷰 흐름 화면에 부착하여 일관된 일시정지 어포던스를 제공.
    func gyPauseToolbar(_ onPause: @escaping () -> Void) -> some View {
        self.toolbar {
            ToolbarItem(placement: gyTopBarTrailing) {
                Button(action: {
                    GyeolHaptic.light()
                    onPause()
                }) {
                    Text("잠시 멈추기")
                        .font(.custom("Pretendard-Medium", fixedSize: 14))
                        .foregroundColor(.gyeolTextTertiary)
                }
                .accessibilityLabel("잠시 멈추기")
            }
        }
    }
}
