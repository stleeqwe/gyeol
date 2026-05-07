// 결 (Gyeol) — Input-focus fade mechanism
// 결_디자인시스템_v1 §3.2 (몰입감 핵심)
//
// 입력 영역 focus 시 형제 UI(질문, 진행바, 탑바, 회피 옵션)를 페이드.
// 사용 예시:
//   @FocusState private var isInputFocused: Bool
//
//   QuestionArea().gyeolFadeOnInput(isInputFocused, level: .question)
//   GyProgressBar(...).gyeolFadeOnInput(isInputFocused, level: .progress)
//   GyeolTopBar(isInputActive: isInputFocused, ...)
//   LinkButton(...).gyeolFadeOnInput(isInputFocused, level: .secondary)

import SwiftUI

public enum GyeolFadeLevel {
    case question  // 질문 영역 — opacity 0.35
    case progress  // 진행 바 — opacity 0.3
    case topBar    // 탑바 — opacity 0.4
    case secondary // 회피 옵션 링크 — opacity 0 (사라짐)

    var fadeOpacity: Double {
        switch self {
        case .question: return 0.35
        case .progress: return 0.3
        case .topBar:   return 0.4
        case .secondary: return 0
        }
    }
}

public extension View {
    /// 입력 영역 focus 시 명세 §3.2의 페이드 적용. 0.3s ease-out.
    func gyeolFadeOnInput(_ active: Bool, level: GyeolFadeLevel = .question) -> some View {
        self
            .opacity(active ? level.fadeOpacity : 1.0)
            .animation(.gyeolFadeUI, value: active)
            // 페이드되어도 VoiceOver는 정상 노출 — 시각만 흐려질 뿐 의미는 유지
            .accessibilityHidden(false)
    }
}
