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
            VStack(spacing: GySpace.lg) {
                Spacer().frame(height: GySpace.section)
                Image(systemName: "circle.dotted")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gyText)
                Text("결")
                    .font(GyType.brand())
                    .foregroundColor(.gyText)
                Text("GYEOL")
                    .font(GyType.subBrand)
                    .tracking(2)
                    .foregroundColor(.gyTextSecondary)
                Spacer().frame(height: GySpace.lg)

                VStack(alignment: .leading, spacing: GySpace.lg) {
                    Text("결은 결혼 또는 매우 진지한 장기 연애를 고민하는 분들을 위한 가치관 매칭 앱입니다.")
                    Text("외모나 스펙보다, 당신이 무엇을 믿고 어디서 물러서지 않는지를 묻습니다.")
                    Text("질문은 가볍지 않습니다. 어떤 질문은 불편할 수 있습니다. 당신의 신념이 어디서 흔들리는지, 어디서 양보할 수 없는지를 마주하게 될 수 있습니다.")
                    Text("그 불편함 속에서 사람의 결이 드러납니다.")
                    Text("가벼운 만남이나 친구를 찾는 분들에게는 부담만 큰 앱입니다.")
                        .foregroundColor(.gyTextTertiary)
                }
                .font(GyType.bodyLG)
                .foregroundColor(.gyText)
                .padding(.horizontal, GySpace.lg)
                Spacer().frame(height: GySpace.xl)
            }
        }
        .background(Color.gyBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: OnboardingRoute.signIn) {
                Text("시작하기")
                    .font(GyType.cta)
                    .foregroundColor(.gyAccentContrast)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.gyAccent)
                    .clipShape(RoundedRectangle(cornerRadius: GyRadius.cta, style: .continuous))
                    .padding(.horizontal, GySpace.lg)
                    .padding(.bottom, GySpace.md)
            }.buttonStyle(.plain)
        }
    }
}

public enum OnboardingRoute: Hashable { case signIn }

// ─── 화면 2: Apple Sign In ──────────────────────────────────

public struct SignInScreen: View {
    @EnvironmentObject var auth: AuthService

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: GySpace.lg) {
            Spacer().frame(height: GySpace.xxl)
            Text("결을 시작하려면\nApple ID로 로그인해주세요.")
                .font(GyType.headlineLG)
                .foregroundColor(.gyText)
                .lineSpacing(8)
            Spacer().frame(height: GySpace.xl)
            Button(action: { auth.startAppleSignIn() }) {
                HStack(spacing: GySpace.xs) {
                    Image(systemName: "applelogo")
                    Text("Apple로 계속하기")
                }
                .font(GyType.cta)
                .foregroundColor(.gyAccentContrast)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.gyAccent)
                .clipShape(RoundedRectangle(cornerRadius: GyRadius.cta, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(auth.isProcessing)

            Text("결은 한 명당 하나의 계정만 허용합니다.")
                .font(GyType.bodySM)
                .foregroundColor(.gyTextTertiary)
                .frame(maxWidth: .infinity)
            if let err = auth.lastError {
                Text(err).font(GyType.bodySM).foregroundColor(.red)
            }
            Spacer()
        }
        .padding(.horizontal, GySpace.lg)
        .background(Color.gyBg.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: GySpace.lg) {
                Text("처리 동의")
                    .font(GyType.headlineLG)
                    .foregroundColor(.gyText)
                Text("결 사용을 위해 다음 5가지에 별도 동의가 필요합니다. 본 동의는 언제든 철회할 수 있습니다.")
                    .font(GyType.bodyMD)
                    .foregroundColor(.gyTextSecondary)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: GySpace.md) {
                    ForEach(items.indices, id: \.self) { i in
                        Button(action: { checks[i].toggle() }) {
                            HStack(alignment: .top, spacing: GySpace.sm) {
                                Image(systemName: checks[i] ? "checkmark.square.fill" : "square")
                                    .foregroundColor(checks[i] ? .gyAccent : .gyDivider)
                                VStack(alignment: .leading, spacing: GySpace.xxs) {
                                    Text(items[i].0).font(GyType.headlineSM).foregroundColor(.gyText)
                                    Text(items[i].1).font(GyType.bodySM).foregroundColor(.gyTextSecondary).lineSpacing(4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: GySpace.lg)
                PrimaryButton("모두 동의하고 시작", isEnabled: checks.allSatisfy({ $0 })) {
                    Task {
                        isProcessing = true
                        defer { isProcessing = false }
                        do {
                            try await auth.recordConsent(consentTextVersion: "v7.0")
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(isProcessing)
                if let errorMessage {
                    Text(errorMessage)
                        .font(GyType.bodySM)
                        .foregroundColor(.red)
                }
            }
            .padding(GySpace.lg)
        }
        .background(Color.gyBg.ignoresSafeArea())
    }
}

// ─── 인터뷰 홈 (영역 선택) ─────────────────────────────────

public struct InterviewHomeScreen: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GySpace.lg) {
                Spacer().frame(height: GySpace.lg)
                Text("6영역의 결을 살펴봅니다.")
                    .font(GyType.headlineLG)
                    .foregroundColor(.gyText)
                Text("한 영역씩 진행해주세요. 답변은 언제든 저장됩니다.")
                    .font(GyType.bodyMD)
                    .foregroundColor(.gyTextSecondary)

                VStack(alignment: .leading, spacing: GySpace.md) {
                    ForEach(DomainID.allCases, id: \.self) { d in
                        NavigationLink(value: InterviewRoute.intro(d)) {
                            HStack {
                                VStack(alignment: .leading, spacing: GySpace.xs) {
                                    Text("영역 0\(d.indexNumber)")
                                        .font(GyType.caption).foregroundColor(.gyTextTertiary)
                                    Text(d.labelKo)
                                        .font(GyType.headlineMD).foregroundColor(.gyText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gyTextTertiary)
                            }
                            .padding(GySpace.lg)
                            .background(Color.gyBgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: GyRadius.lg))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("명시 Dealbreaker")
                    .font(GyType.caption)
                    .foregroundColor(.gyTextTertiary)
                VStack(alignment: .leading, spacing: GySpace.md) {
                    ForEach(DomainID.allCases, id: \.self) { d in
                        NavigationLink(value: InterviewRoute.dealbreaker(d)) {
                            HStack {
                                Text(d.labelKo)
                                    .font(GyType.headlineSM)
                                    .foregroundColor(.gyText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gyTextTertiary)
                            }
                            .padding(GySpace.md)
                            .background(Color.gyBgSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: GyRadius.md))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: GySpace.xl)
                NavigationLink(value: InterviewRoute.review) {
                    HStack {
                        Text("발행 직전 본인 검토")
                            .font(GyType.headlineSM)
                            .foregroundColor(.gyText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gyTextTertiary)
                    }
                    .padding(GySpace.lg)
                    .background(Color.gyBgSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: GyRadius.md))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, GySpace.lg)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("인터뷰")
        .gyNavigationBarTitleDisplayModeInline()
        .navigationDestination(for: InterviewRoute.self) { r in
            switch r {
            case .intro(let d): InterviewIntroScreen(domain: d)
            case .dealbreaker(let d): DealbreakerInputScreen(domain: d)
            case .review: SelfReviewScreen()
            }
        }
    }
}

public enum InterviewRoute: Hashable {
    case intro(DomainID)
    case dealbreaker(DomainID)
    case review
}
