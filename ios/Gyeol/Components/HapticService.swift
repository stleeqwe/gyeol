// 결 (Gyeol) — Haptic feedback policy
// 결_디자인시스템_v1 §1.7 / §3.5
// 본 앱 햅틱 절제. light가 디폴트. 매칭 성립만 notification.success 단 1회.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum GyeolHaptic {
    /// 일반 버튼 탭, 마이크 토글
    public static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// 답변 완료, 다음 영역으로, 관심 있어요 (주요 액션)
    public static func medium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// 라디오/체크 변경, 토글
    public static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// 매칭 성립 — 단 1회만 사용
    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// 에러, 검증 실패
    public static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
