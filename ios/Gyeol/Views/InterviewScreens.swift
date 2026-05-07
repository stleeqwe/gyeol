// 결 (Gyeol) — 화면 3, 4, 4·A, 4·B, 4·C, 5, 6, 7

import SwiftData
import SwiftUI
import GyeolCore
import GyeolDomain

// ─── 화면 3: 영역 인터뷰 (오픈 질문) ─────────────────────

public struct InterviewIntroScreen: View {
    @ObservedObject var vm: InterviewViewModel
    @EnvironmentObject var coord: InterviewFlowCoordinator
    @State private var showSkip: Bool = false
    @State private var showPrivate: Bool = false

    public init(vm: InterviewViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolLG) {
            HStack {
                Text("영역 0\(vm.domain.indexNumber)")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Spacer()
                Text("\(vm.domain.indexNumber) / 6")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
            }
            GyProgressBar(current: vm.domain.indexNumber, total: 6)

            Spacer().frame(height: .gyeolLG)
            Text(vm.domain.labelKo)
                .gyeolStyle(.bodyLarge)
                .foregroundColor(.gyeolTextPrimary)

            Spacer().frame(height: .gyeol2XL)
            Text(vm.openQuestion.primary)
                .gyeolStyle(.title1)
                .foregroundColor(.gyeolTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let s = vm.openQuestion.secondary {
                Text(s)
                    .gyeolStyle(.title1)
                    .foregroundColor(.gyeolTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()

            HStack(spacing: .gyeolMD) {
                LinkButton("더 쉽게 설명해주세요") {
                    GyeolHaptic.selection()
                    vm.easierMode()
                }
                LinkButton("건너뛸게요") {
                    GyLog.ui.info("interview.skip_modal_open", fields: ["domain": vm.domain.rawValue])
                    showSkip = true
                }
                LinkButton("비공개로 보관") {
                    GyLog.ui.info("interview.private_modal_open", fields: ["domain": vm.domain.rawValue])
                    showPrivate = true
                }
                Spacer()
            }
            Divider().background(Color.gyeolDivider)
            PrimaryButton("답변 시작하기") {
                GyLog.ui.info("interview.start_answer_tap", fields: ["domain": vm.domain.rawValue])
                GyeolHaptic.medium()
                coord.advanceFromIntroToAnswer(domain: vm.domain)
            }
        }
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyTrackAppear("InterviewIntroScreen", fields: ["domain": vm.domain.rawValue])
        .overlay {
            if showSkip {
                SkipReasonModal(
                    onSelect: { reason in
                        Task {
                            await vm.skip(reason: reason)
                            showSkip = false
                            coord.advanceAfterAvoidanceAction(domain: vm.domain)
                        }
                    },
                    onCancel: { showSkip = false }
                )
                .background(Color.black.opacity(0.4).ignoresSafeArea())
            }
            if showPrivate {
                PrivateKeepModal(
                    onConfirm: {
                        Task {
                            await vm.keepPrivate()
                            showPrivate = false
                            coord.advanceAfterAvoidanceAction(domain: vm.domain)
                        }
                    },
                    onCancel: { showPrivate = false }
                )
                .background(Color.black.opacity(0.4).ignoresSafeArea())
            }
        }
        .gyPauseToolbar { coord.pause() }
    }
}

// ─── 화면 4: 답변 입력 (키보드/음성 4단계 통합) ────────

public struct AnswerInputScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var coord: InterviewFlowCoordinator
    @ObservedObject var vm: InterviewViewModel
    let isOpenQuestion: Bool
    @StateObject private var speech = SpeechService()
    @State private var showPermissionModal: Bool = false
    @FocusState private var isInputFocused: Bool

    public init(vm: InterviewViewModel, isOpenQuestion: Bool) {
        self.vm = vm
        self.isOpenQuestion = isOpenQuestion
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolMD) {
            HStack {
                Text("\(vm.domain.indexNumber) / 6")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Spacer()
            }
            .gyeolFadeOnInput(isInputFocused, level: .topBar)

            GyProgressBar(current: vm.domain.indexNumber, total: 6)
                .gyeolFadeOnInput(isInputFocused, level: .progress)

            Group {
                if isOpenQuestion {
                    Text("\(vm.openQuestion.primary) \(vm.openQuestion.secondary ?? "")")
                        .gyeolStyle(.body)
                        .foregroundColor(.gyeolTextTertiary)
                } else if let q = vm.followUpQuestion {
                    VStack(alignment: .leading, spacing: .gyeolSM) {
                        Text("결")
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextSecondary)
                        Text(q)
                            .gyeolStyle(.title1)
                            .foregroundColor(.gyeolTextPrimary)
                    }
                }
            }
            .gyeolFadeOnInput(isInputFocused, level: .question)

            HStack {
                Spacer()
                MicButton(state: micState) {
                    GyeolHaptic.light()
                    onMicTap()
                }
            }

            ZStack(alignment: .topLeading) {
                if vm.currentDraft.isEmpty && !speech.isRecording {
                    Text("답변을 적어주세요.")
                        .gyeolStyle(.body)
                        .foregroundColor(.gyeolTextTertiary.opacity(0.55))
                        .padding(.gyeolMD)
                }
                TextEditor(text: $vm.currentDraft)
                    .focused($isInputFocused)
                    .gyeolStyle(.body)
                    .foregroundColor(.gyeolTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.gyeolSM)
                    .frame(minHeight: 200)
            }

            if speech.isRecording {
                RecordingBanner(elapsedSeconds: speech.elapsedSeconds)
                Spacer()
                WaveformView(amplitude: speech.amplitude)
            } else if !vm.currentDraft.isEmpty {
                Text(speech.transcript.isEmpty ? "글자 수에 제한 없습니다. 생각의 흐름을 그대로 적어주세요." : "음성으로 받은 텍스트입니다. 필요하면 자유롭게 수정해주세요.")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Spacer()
            } else {
                Spacer()
            }

            HStack(spacing: .gyeolMD) {
                if !isOpenQuestion {
                    LinkButton("더 쉽게 설명해주세요") { vm.easierMode() }
                        .gyeolFadeOnInput(isInputFocused, level: .secondary)
                }
                Spacer()
            }

            if speech.isRecording {
                StopRecordingButton {
                    GyLog.ui.info("answer.stop_recording_tap", fields: [
                        "domain": vm.domain.rawValue,
                        "elapsed_seconds": String(speech.elapsedSeconds),
                    ])
                    GyeolHaptic.light()
                    speech.stop()
                    if !speech.transcript.isEmpty {
                        vm.currentDraft = speech.transcript
                    }
                }
            } else {
                PrimaryButton("답변 완료") {
                    GyLog.ui.info("answer.complete_tap", fields: [
                        "domain": vm.domain.rawValue,
                        "is_open_question": String(isOpenQuestion),
                        "draft_chars": String(vm.currentDraft.count),
                        "voice_used": String(!speech.transcript.isEmpty),
                    ])
                    GyeolHaptic.medium()
                    Task {
                        let previousAnswerCount = vm.answers.count
                        let voiceSeconds = speech.transcript.isEmpty ? nil : speech.elapsedSeconds
                        if isOpenQuestion {
                            await vm.submitOpenAnswer(voiceInputSeconds: voiceSeconds)
                        } else {
                            await vm.submitFollowUpAnswer(voiceInputSeconds: voiceSeconds)
                        }
                        if vm.answers.count > previousAnswerCount {
                            clearDraft()
                            coord.advanceFromAnswerToLoading(domain: vm.domain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyPauseToolbar { coord.pause() }
        .onChange(of: speech.transcript) { _, new in
            if !new.isEmpty { vm.currentDraft = new }
        }
        .gyTrackAppear("AnswerInputScreen", fields: [
            "domain": vm.domain.rawValue,
            "is_open_question": String(isOpenQuestion),
        ])
        .onAppear { restoreDraft() }
        .onChange(of: vm.currentDraft) { _, _ in saveDraft() }
        .overlay {
            if showPermissionModal {
                permissionModal
                    .background(Color.black.opacity(0.4).ignoresSafeArea())
            }
        }
    }

    private var micState: MicState {
        if speech.permissionStatus == .denied { return .denied }
        if speech.isRecording { return .recording }
        return .inactive
    }

    private var draftKey: String {
        DraftStore.makeKey(
            domain: vm.domain,
            isOpenQuestion: isOpenQuestion,
            followUpQuestion: vm.followUpQuestion
        )
    }

    private func restoreDraft() {
        guard vm.currentDraft.isEmpty,
              let draft = DraftStore.load(context: modelContext, key: draftKey) else { return }
        vm.currentDraft = draft
    }

    private func saveDraft() {
        DraftStore.upsert(
            context: modelContext,
            key: draftKey,
            domain: vm.domain,
            seq: (vm.answers.map { $0.seq }.max() ?? 0) + 1,
            isOpenQuestionAnswer: isOpenQuestion,
            followUpQuestionText: vm.followUpQuestion,
            text: vm.currentDraft,
            depthLevel: vm.currentDepth,
            voiceInputSeconds: speech.transcript.isEmpty ? nil : speech.elapsedSeconds
        )
    }

    private func clearDraft() {
        DraftStore.delete(context: modelContext, key: draftKey)
    }

    private func onMicTap() {
        GyLog.ui.info("answer.mic_tap", fields: [
            "permission": "\(speech.permissionStatus)",
            "is_recording": String(speech.isRecording),
        ])
        switch speech.permissionStatus {
        case .notDetermined:
            showPermissionModal = true
        case .denied:
            // 안내만 (설정 앱 유도)
            break
        case .granted:
            if speech.isRecording { speech.stop() } else { speech.start() }
        }
    }

    private var permissionModal: some View {
        GyModal(
            title: "'결'이 음성 인식에 접근하려고 합니다",
            primaryLabel: "허용",
            secondaryLabel: "허용 안 함",
            onPrimary: {
                Task {
                    await speech.requestPermissions()
                    showPermissionModal = false
                    if speech.permissionStatus == .granted { speech.start() }
                }
            },
            onSecondary: { showPermissionModal = false }
        ) {
            Text("음성으로 답변을 입력할 수 있도록 마이크와 음성 인식 사용을 허용해주세요. 음성은 기기에서 직접 처리되며 외부로 전송되지 않습니다.")
        }
    }
}

// ─── 화면 5: 후속 질문 생성 중 ────────────────────────────

public struct FollowUpLoadingScreen: View {
    @EnvironmentObject var coord: InterviewFlowCoordinator
    @ObservedObject var vm: InterviewViewModel
    @State private var advanced: Bool = false

    public init(vm: InterviewViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: .gyeolXL) {
            Spacer()
            LoadingDots()
            Text("당신의 답을 읽고 있습니다.")
                .gyeolStyle(.body)
                .foregroundColor(.gyeolTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyNavigationBarHidden()
        .gyTrackAppear("FollowUpLoadingScreen", fields: ["domain": vm.domain.rawValue])
        .gyPauseToolbar { coord.pause() }
        .task {
            let waitStart = CFAbsoluteTimeGetCurrent()
            GyLog.interview.info("follow_up_wait.start", fields: [
                "domain": vm.domain.rawValue,
                "answers": String(vm.answers.count),
            ])
            // 잠시 대기 → followUpQuestion 또는 영역 종료
            var nextStep: String = "stuck"
            while !advanced {
                try? await Task.sleep(for: .milliseconds(400))
                if vm.followUpQuestion != nil, !vm.pendingFollowUp {
                    advanced = true
                    nextStep = "follow_up"
                    coord.advanceFromLoadingToFollowUpAnswer(domain: vm.domain)
                    break
                }
                if vm.answers.count >= 5 || (!vm.pendingFollowUp && vm.followUpQuestion == nil) {
                    if vm.answers.count >= 3 {
                        advanced = true
                        nextStep = "domain_end"
                        coord.advanceFromLoadingToEnd(domain: vm.domain)
                        break
                    }
                }
            }
            let waitMs = Int((CFAbsoluteTimeGetCurrent() - waitStart) * 1000)
            GyLog.interview.info("follow_up_wait.done", fields: [
                "domain": vm.domain.rawValue,
                "duration_ms": String(waitMs),
                "next": nextStep,
            ])
        }
    }
}

// ─── 화면 7: 영역 종료 ────────────────────────────────────

public struct DomainEndScreen: View {
    @EnvironmentObject var coord: InterviewFlowCoordinator
    @ObservedObject var vm: InterviewViewModel

    public init(vm: InterviewViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolLG) {
            Spacer()
            Text("영역 0\(vm.domain.indexNumber) — \(vm.domain.labelKo)")
                .gyeolStyle(.caption2)
                .foregroundColor(.gyeolTextTertiary)
            Text("답변이 끝났습니다.")
                .gyeolStyle(.title1)
                .foregroundColor(.gyeolTextPrimary)
            Text("분석은 6영역이 모두 끝난 후 한 번에 정리되어 보여드립니다.")
                .gyeolStyle(.body)
                .foregroundColor(.gyeolTextSecondary)

            Spacer()
            if let next = nextDomain() {
                Text("다음 영역")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Text("영역 0\(next.indexNumber) — \(next.labelKo)")
                    .gyeolStyle(.bodyLarge)
                    .foregroundColor(.gyeolTextPrimary)
            } else {
                Text("이제 만나고 싶지 않은 결을 적습니다.")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                Text("Dealbreaker — 발행 직전 마지막 단계")
                    .gyeolStyle(.bodyLarge)
                    .foregroundColor(.gyeolTextPrimary)
            }
            Spacer().frame(height: .gyeolLG)
            PrimaryButton(nextDomain() != nil ? "다음 영역으로" : "Dealbreaker로") {
                GyLog.ui.info("domain_end.next_tap", fields: [
                    "domain": vm.domain.rawValue,
                    "has_next": String(nextDomain() != nil),
                ])
                GyeolHaptic.medium()
                Task {
                    await vm.finalizeDomain()
                    coord.advanceFromDomainEnd(domain: vm.domain)
                }
            }
            LinkButton("잠시 쉬었다 할게요") {
                GyLog.ui.info("domain_end.pause_tap", fields: ["domain": vm.domain.rawValue])
                Task {
                    await vm.finalizeDomain()
                    coord.pause()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, .gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyNavigationBarHidden()
        .gyPauseToolbar { coord.pause() }
        .gyTrackAppear("DomainEndScreen", fields: ["domain": vm.domain.rawValue])
    }

    private func nextDomain() -> DomainID? {
        let idx = vm.domain.indexNumber
        return DomainID.allCases.first(where: { $0.indexNumber == idx + 1 })
    }
}

// ─── 회피 모달들 ────────────────────────────────────────

public struct SkipReasonModal: View {
    let onSelect: (SkipReason) -> Void
    let onCancel: () -> Void
    @State private var selected: SkipReason = .do_not_want_public

    public var body: some View {
        GyModal(
            title: "이 영역을 건너뛰는 사유를 선택해주세요.",
            primaryLabel: "확인",
            secondaryLabel: "취소",
            onPrimary: { onSelect(selected) },
            onSecondary: onCancel
        ) {
            VStack(alignment: .leading, spacing: GySpace.sm) {
                ForEach(SkipReason.allCases, id: \.self) { r in
                    ChoiceChip(label: r.labelKo, isSelected: selected == r) { selected = r }
                }
                Spacer().frame(height: GySpace.xs)
                Divider().background(Color.gyDivider)
                Text("선택한 사유는 매칭된 상대에게 노출됩니다.")
                    .font(GyType.bodySM).foregroundColor(.gyTextTertiary)
                Text("예: \"이 영역은 답변하지 않았습니다 — 사유: \(selected.labelKo)\"")
                    .font(GyType.bodySM).foregroundColor(.gyTextSecondary)
            }
        }
    }
}

public struct PrivateKeepModal: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public var body: some View {
        GyModal(
            title: "이 영역의 답변을 비공개로 보관합니다.",
            primaryLabel: "비공개로 보관",
            secondaryLabel: "취소",
            onPrimary: onConfirm,
            onSecondary: onCancel
        ) {
            VStack(alignment: .leading, spacing: GySpace.xs) {
                Text("이 선택의 영향:").font(GyType.bodySM).foregroundColor(.gyText)
                Text("· 분석 내용은 매칭 상대에게 공개되지 않습니다.")
                Text("· 추천 후보에게 \"이 영역은 비공개로 보관됨\" 상태만 표시됩니다.")
                Text("· 매칭 풀 자격 산정에서 이 영역은 발행으로 카운트되지 않습니다.")
                Text("· 비공개 영역이 늘어날수록 매칭 가능성이 줄어듭니다.")
            }
        }
    }
}
