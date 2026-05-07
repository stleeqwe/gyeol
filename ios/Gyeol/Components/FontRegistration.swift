// 결 (Gyeol) — Custom font registration
// Pretendard .ttf 파일을 App 타겟 Resources/Fonts/에 두면 launch 시 자동 등록.
// 미적재 시 Font.custom("Pretendard-…")는 SwiftUI 기본으로 system font fallback.

import CoreText
import Foundation

public enum FontRegistration {
    private static var didRegister = false

    /// App lifecycle 진입 시 1회 호출. 동일 폰트 재등록은 no-op.
    public static func registerOnce() {
        guard !didRegister else { return }
        didRegister = true

        let bundle = Bundle.main
        let ttfURLs = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        let unique = Array(Set(ttfURLs))
        guard !unique.isEmpty else { return }

        var registered = 0
        for url in unique {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                registered += 1
            }
        }
        if registered > 0 {
            print("[GyeolUI] Registered \(registered) custom font(s) from main bundle.")
        }
    }
}
