// 결 (Gyeol) — 화면 1, 2, 동의서, 메인 메뉴
// 화면설계 v2 §2 (온보딩 게이트), §3 (Apple Sign In), v7 동의서

import SwiftUI
import GyeolCore
import GyeolDomain

// ─── 화면 1: 온보딩 게이트 ─────────────────────────────────

public struct OnboardingScreen: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: .gyeolLG) {
                Spacer().frame(height: .gyeol4XL)
                Image(systemName: "circle.dotted")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gyeolTextPrimary)
                Text("결")
                    .gyeolStyle(.display)
                    .foregroundColor(.gyeolTextPrimary)
                Text("GYEOL")
                    .font(.custom("Pretendard-Medium", fixedSize: 11))
                    .kerning(2)
                    .foregroundColor(.gyeolTextSecondary)
                Spacer().frame(height: .gyeolLG)

                VStack(alignment: .leading, spacing: .gyeolLG) {
                    Text("결은 결혼 또는 매우 진지한 장기 연애를 고민하는 분들을 위한 가치관 매칭 앱입니다.")
                    Text("외모나 스펙보다, 당신이 무엇을 믿고 어디서 물러서지 않는지를 묻습니다.")
                    Text("질문은 가볍지 않습니다. 어떤 질문은 불편할 수 있습니다. 당신의 신념이 어디서 흔들리는지, 어디서 양보할 수 없는지를 마주하게 될 수 있습니다.")
                    Text("그 불편함 속에서 사람의 결이 드러납니다.")
                    Text("가벼운 만남이나 친구를 찾는 분들에게는 부담만 큰 앱입니다.")
                        .foregroundColor(.gyeolTextTertiary)
                }
                .gyeolStyle(.body)
                .foregroundColor(.gyeolTextPrimary)
                .padding(.horizontal, .gyeolLG)
                Spacer().frame(height: .gyeolXL)
            }
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: OnboardingRoute.signIn) {
                HStack {
                    Spacer()
                    Text("시작하기").gyeolStyle(.cta)
                    Spacer()
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                GyLog.ui.info("onboarding.cta_tap", fields: ["route": "sign_in"])
                GyeolHaptic.medium()
            })
            .buttonStyle(GyeolPrimaryButtonStyle())
            .padding(.horizontal, .gyeolLG)
            .padding(.bottom, .gyeolMD)
        }
        .gyTrackAppear("OnboardingScreen")
    }
}

public enum OnboardingRoute: Hashable { case signIn }

// ─── 화면 2: Apple Sign In ──────────────────────────────────

public struct SignInScreen: View {
    @EnvironmentObject var auth: AuthService

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolLG) {
            Spacer().frame(height: .gyeol2XL)
            Text("결을 시작하려면\nApple ID로 로그인해주세요.")
                .gyeolStyle(.title1)
                .foregroundColor(.gyeolTextPrimary)
            Spacer().frame(height: .gyeolXL)
            Button(action: {
                GyLog.ui.info("sign_in.cta_tap")
                GyeolHaptic.medium()
                auth.startAppleSignIn()
            }) {
                HStack(spacing: .gyeolSM) {
                    Image(systemName: "applelogo")
                    Text("Apple로 계속하기").gyeolStyle(.cta)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GyeolPrimaryButtonStyle())
            .disabled(auth.isProcessing)

            Text("결은 한 명당 하나의 계정만 허용합니다.")
                .gyeolStyle(.caption2)
                .foregroundColor(.gyeolTextTertiary)
                .frame(maxWidth: .infinity)
            if let err = auth.lastError {
                Text(err).gyeolStyle(.caption2).foregroundColor(.red)
            }
            Spacer()
        }
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyTrackAppear("SignInScreen")
    }
}

// ─── 동의서 (PIPA 23조) ────────────────────────────────────

public struct ConsentScreen: View {
    @EnvironmentObject var auth: AuthService
    @State private var checks: [Bool] = Array(repeating: false, count: 5)
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    public init() {}

    private let items: [(String, String)] = [
        ("민감정보 처리 별도 동의", "신념·가족·성·가치관 등 민감정보를 매칭 목적에 한해 처리합니다."),
        ("음성 on-device 처리 고지", "음성 입력은 기기 내에서 직접 텍스트로 변환됩니다. 음성 자체는 외부로 전송되지 않습니다."),
        ("Raw quote 격리 고지", "당신의 답변에서 직접 인용은 본인 검토 화면에서만 보이며 매칭 상대에게 노출되지 않습니다."),
        ("AI 학습 미사용 고지", "당신의 답변은 외부 AI 학습 데이터로 사용되지 않습니다."),
        ("한국 데이터 거주 고지", "데이터는 한국(서울 리전)에 저장되며 한국 외 지역으로 이전되지 않습니다.")
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolLG) {
                Text("처리 동의")
                    .gyeolStyle(.title1)
                    .foregroundColor(.gyeolTextPrimary)
                Text("결 사용을 위해 다음 5가지에 별도 동의가 필요합니다. 본 동의는 언제든 철회할 수 있습니다.")
                    .gyeolStyle(.body)
                    .foregroundColor(.gyeolTextSecondary)

                VStack(alignment: .leading, spacing: .gyeolMD) {
                    ForEach(items.indices, id: \.self) { i in
                        Button(action: {
                            GyeolHaptic.selection()
                            checks[i].toggle()
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: checks[i] ? "checkmark.square.fill" : "square")
                                    .foregroundColor(checks[i] ? .gyeolAccentPrimary : .gyeolBorder)
                                VStack(alignment: .leading, spacing: .gyeolXS) {
                                    Text(items[i].0)
                                        .gyeolStyle(.bodyLarge)
                                        .foregroundColor(.gyeolTextPrimary)
                                    Text(items[i].1)
                                        .gyeolStyle(.caption2)
                                        .foregroundColor(.gyeolTextSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: .gyeolLG)
                PrimaryButton("모두 동의하고 시작", isEnabled: checks.allSatisfy({ $0 })) {
                    GyLog.ui.info("consent.confirm_tap", fields: [
                        "all_checked": String(checks.allSatisfy { $0 }),
                    ])
                    GyeolHaptic.medium()
                    Task {
                        isProcessing = true
                        defer { isProcessing = false }
                        do {
                            try await auth.recordConsent(consentTextVersion: "v7.0")
                        } catch {
                            errorMessage = error.localizedDescription
                            GyeolHaptic.error()
                            GyLog.auth.error("consent.record_failed", error: error)
                        }
                    }
                }
                .disabled(isProcessing)
                if let errorMessage {
                    Text(errorMessage)
                        .gyeolStyle(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.gyeolLG)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyTrackAppear("ConsentScreen")
    }
}

// InterviewHomeScreen + InterviewRoute는 발행 전 선형 흐름 도입과 함께 제거됨
// (이전 hub-style 진입점 → InterviewShellView로 대체. RootView가 publishState로 분기.)
