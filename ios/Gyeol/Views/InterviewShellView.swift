// 결 (Gyeol) — 발행 전 인터뷰 셸 (탭바 없는 선형 흐름)
// 가입 + 동의 직후 RootView가 이 화면으로 분기. 발행 후 MainTabView로 전환.

import SwiftUI
import GyeolCore
import GyeolDomain

public struct InterviewShellView: View {
    @StateObject private var coord: InterviewFlowCoordinator

    public init(initialCursor: ResumeCursor, auth: AuthService) {
        _coord = StateObject(wrappedValue: InterviewFlowCoordinator(initialCursor: initialCursor, auth: auth))
    }

    public var body: some View {
        Group {
            if coord.isPaused {
                PausedView { coord.resume() }
            } else {
                NavigationStack(path: $coord.path) {
                    rootView
                        .navigationDestination(for: InterviewFlowStep.self, destination: destination)
                }
                .environmentObject(coord)
            }
        }
        .background(Color.gyBg.ignoresSafeArea())
        .onAppear {
            // 신규 가입자(.fresh)는 랜딩 없이 바로 1번 영역 인트로로.
            if case .fresh = coord.initialCursor, coord.path.isEmpty {
                coord.start()
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if case .fresh = coord.initialCursor {
            // 잠깐 노출 — onAppear에서 .domainIntro(.belief)을 push하면 즉시 가려짐.
            Color.gyBg.ignoresSafeArea()
        } else {
            ResumeLandingView(cursor: coord.initialCursor) { coord.start() }
        }
    }

    @ViewBuilder
    private func destination(for step: InterviewFlowStep) -> some View {
        switch step {
        case .domainIntro(let d):
            InterviewIntroScreen(vm: coord.vm(for: d))
        case .domainAnswer(let d, let isOpen):
            AnswerInputScreen(vm: coord.vm(for: d), isOpenQuestion: isOpen)
        case .domainFollowUpLoading(let d):
            FollowUpLoadingScreen(vm: coord.vm(for: d))
        case .domainEnd(let d):
            DomainEndScreen(vm: coord.vm(for: d))
        case .dealbreakers:
            DealbreakersScreen()
        case .selfReview:
            SelfReviewScreen()
        }
    }
}


// ─── 이어서 시작 랜딩 ──────────────────────────────────────

struct ResumeLandingView: View {
    let cursor: ResumeCursor
    let onContinue: () -> Void
    @State private var completedCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: .gyeolLG) {
            Spacer()
            Text("이어서 진행하시겠어요?")
                .gyeolStyle(.title1)
                .foregroundColor(.gyeolTextPrimary)

            Spacer().frame(height: .gyeolMD)
            VStack(alignment: .leading, spacing: .gyeolSM) {
                Text(stageCaption)
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Text(stageTitle)
                    .gyeolStyle(.bodyLarge)
                    .foregroundColor(.gyeolTextPrimary)
            }

            Spacer().frame(height: .gyeolLG)
            GyProgressBar(current: completedCount, total: 6)
            Text("\(completedCount) / 6 영역 완료")
                .gyeolStyle(.caption2)
                .foregroundColor(.gyeolTextTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("이어서 시작하기") {
                GyeolHaptic.medium()
                onContinue()
            }
            .padding(.bottom, .gyeolMD)
        }
        .task { await loadProgress() }
        .gyTrackAppear("ResumeLandingView", fields: ["cursor": cursor.shortLabel])
    }

    private var stageCaption: String {
        if let d = cursor.nextDomain { return "영역 0\(d.indexNumber)" }
        if case .dealbreakers = cursor { return "Dealbreaker" }
        return ""
    }

    private var stageTitle: String {
        if let d = cursor.nextDomain { return d.labelKo }
        if case .dealbreakers = cursor { return "만나고 싶지 않은 결" }
        return ""
    }

    private func loadProgress() async {
        do {
            let interviews = try await InterviewService.shared.loadOwnInterviews()
            let done = interviews.filter {
                $0.status == .finalized || $0.status == .skipped || $0.status == .private_kept
            }.count
            self.completedCount = done
        } catch {
            GyLog.ui.warn("resume_landing.progress_load_failed", fields: ["error": error.localizedDescription])
        }
    }
}

private extension ResumeCursor {
    var nextDomain: DomainID? {
        switch self {
        case .domainIntro(let d), .domainInProgress(let d): return d
        case .fresh, .dealbreakers: return nil
        }
    }
}

// ─── 잠시 멈춤 ───────────────────────────────────────────

struct PausedView: View {
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .gyeolMD) {
            Spacer()
            Text("잠시 멈췄습니다.")
                .gyeolStyle(.title1)
                .foregroundColor(.gyeolTextPrimary)
            Text("언제든 돌아오세요. 답변은 그대로 보관됩니다.")
                .gyeolStyle(.body)
                .foregroundColor(.gyeolTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("이어서 시작하기") {
                GyeolHaptic.medium()
                onResume()
            }
            .padding(.bottom, .gyeolMD)
        }
        .gyTrackAppear("PausedView")
    }
}
