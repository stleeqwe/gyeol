// 결 (Gyeol) — 화면 3, 4, 4·A, 4·B, 4·C, 5, 6, 7

import SwiftData
import SwiftUI
import GyeolCore
import GyeolDomain

// ─── 화면 3: 영역 인터뷰 (오픈 질문) ─────────────────────

public struct InterviewIntroScreen: View {
    @StateObject private var vm: InterviewViewModel
    @State private var showSkip: Bool = false
    @State private var showPrivate: Bool = false
    @State private var goAnswer: Bool = false

    public init(domain: DomainID) {
        _vm = StateObject(wrappedValue: InterviewViewModel(domain: domain))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GySpace.lg) {
            HStack {
                Text("영역 0\(vm.domain.indexNumber)")
                    .font(GyType.caption).foregroundColor(.gyTextTertiary)
                Spacer()
                Text("\(vm.domain.indexNumber) / 6")
                    .font(GyType.caption).foregroundColor(.gyTextTertiary)
            }
            GyProgressBar(current: vm.domain.indexNumber, total: 6)

            Spacer().frame(height: GySpace.lg)
            Text(vm.domain.labelKo)
                .font(GyType.headlineMD).foregroundColor(.gyText)

            Spacer().frame(height: GySpace.xxl)
            Text(vm.openQuestion.primary)
                .font(GyType.headlineLG).foregroundColor(.gyText)
                .lineSpacing(8).fixedSize(horizontal: false, vertical: true)
            if let s = vm.openQuestion.secondary {
                Text(s).font(GyType.headlineLG)
                    .foregroundColor(.gyTextSecondary)
                    .lineSpacing(8).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()

            HStack(spacing: GySpace.lg) {
                SecondaryButton("더 쉽게 설명해주세요") { vm.easierMode() }
                SecondaryButton("건너뛸게요") { showSkip = true }
                Spacer()
            }
            Divider().background(Color.gyDivider)
            PrimaryButton("답변 시작하기") { goAnswer = true }
        }
        .padding(.horizontal, GySpace.lg)
        .background(Color.gyBg.ignoresSafeArea())
        .navigationDestination(isPresented: $goAnswer) {
            AnswerInputScreen(vm: vm, isOpenQuestion: true)
        }
        .task { await vm.bootstrap() }
        .overlay {
            if showSkip {
                SkipReasonModal(
                    onSelect: { reason in
                        Task { await vm.skip(reason: reason); showSkip = false }
                    },
                    onCancel: { showSkip = false }
                )
                .background(Color.black.opacity(0.4).ignoresSafeArea())
            }
            if showPrivate {
                PrivateKeepModal(
                    onConfirm: {
                        Task { await vm.keepPrivate(); showPrivate = false }
                    },
                    onCancel: { showPrivate = false }
                )
                .background(Color.black.opacity(0.4).ignoresSafeArea())
            }
        }
        .toolbar {
            ToolbarItem(placement: gyTopBarTrailing) {
                Button("비공개") { showPrivate = true }
                    .font(GyType.bodySM).foregroundColor(.gyTextSecondary)
            }
        }
    }
}

// ─── 화면 4: 답변 입력 (키보드/음성 4단계 통합) ────────

public struct AnswerInputScreen: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var vm: InterviewViewModel
    let isOpenQuestion: Bool
    @StateObject private var speech = SpeechService()
    @State private var goNext: Bool = false
    @State private var showPermissionModal: Bool = false

    public init(vm: InterviewViewModel, isOpenQuestion: Bool) {
        self.vm = vm
        self.isOpenQuestion = isOpenQuestion
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GySpace.md) {
            HStack {
                Text("\(vm.domain.indexNumber) / 6")
                    .font(GyType.caption).foregroundColor(.gyTextTertiary)
                Spacer()
            }
            GyProgressBar(current: vm.domain.indexNumber, total: 6)

            Group {
                if isOpenQuestion {
                    Text("\(vm.openQuestion.primary) \(vm.openQuestion.secondary ?? "")")
                        .font(GyType.bodyMD).foregroundColor(.gyTextTertiary).lineSpacing(4)
                } else if let q = vm.followUpQuestion {
                    VStack(alignment: .leading, spacing: GySpace.xs) {
                        Text("결").font(GyType.caption).foregroundColor(.gyTextSecondary)
                        Text(q).font(GyType.headlineLG).foregroundColor(.gyText).lineSpacing(8)
                    }
                }
            }

            HStack {
                Spacer()
                MicButton(state: micState) { onMicTap() }
            }

            ZStack(alignment: .topLeading) {
                if vm.currentDraft.isEmpty && !speech.isRecording {
                    Text("답변을 적어주세요.")
                        .font(GyType.bodyLG)
                        .foregroundColor(.gyTextDisabled)
                        .padding(GySpace.md)
                }
                TextEditor(text: $vm.currentDraft)
                    .font(GyType.bodyLG)
                    .foregroundColor(.gyText)
                    .scrollContentBackground(.hidden)
                    .padding(GySpace.xs)
                    .frame(minHeight: 200)
                    .background(Color.gyBgSubtle.opacity(0.0))
            }

            if speech.isRecording {
                RecordingBanner(elapsedSeconds: speech.elapsedSeconds)
                Spacer()
                WaveformView(amplitude: speech.amplitude)
            } else if !vm.currentDraft.isEmpty {
                Text(speech.transcript.isEmpty ? "글자 수에 제한 없습니다. 생각의 흐름을 그대로 적어주세요." : "음성으로 받은 텍스트입니다. 필요하면 자유롭게 수정해주세요.")
                    .font(GyType.bodySM).foregroundColor(.gyTextTertiary)
                Spacer()
            } else {
                Spacer()
            }

            HStack(spacing: GySpace.md) {
                if !isOpenQuestion {
                    SecondaryButton("더 쉽게 설명해주세요") { vm.easierMode() }
                }
                Spacer()
            }

            PrimaryButton(speech.isRecording ? "녹음 종료" : "답변 완료") {
                if speech.isRecording {
                    speech.stop()
                    if !speech.transcript.isEmpty {
                        vm.currentDraft = speech.transcript
                    }
                } else {
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
                            goNext = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, GySpace.lg)
        .background(Color.gyBg.ignoresSafeArea())
        .navigationDestination(isPresented: $goNext) {
            FollowUpLoadingScreen(vm: vm)
        }
        .onChange(of: speech.transcript) { _, new in
            if !new.isEmpty { vm.currentDraft = new }
        }
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
    @ObservedObject var vm: InterviewViewModel
    @State private var pulse: Bool = false
    @State private var goFollowUp: Bool = false
    @State private var goEnd: Bool = false

    public init(vm: InterviewViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: GySpace.xl) {
            Spacer()
            HStack(spacing: GySpace.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.gyAccent.opacity(pulse ? 0.4 + 0.2 * Double(i) : 0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse.toggle() }
            }
            Text("당신의 답을 읽고 있습니다.")
                .font(GyType.bodyLG).foregroundColor(.gyTextSecondary)
            Spacer()
        }
        .background(Color.gyBg.ignoresSafeArea())
        .gyNavigationBarHidden()
        .task {
            // 잠시 대기 → followUpQuestion 또는 영역 종료
            while !goFollowUp && !goEnd {
                try? await Task.sleep(for: .milliseconds(400))
                if let _ = vm.followUpQuestion, !vm.pendingFollowUp {
                    goFollowUp = true
                    break
                }
                if vm.answers.count >= 5 || (!vm.pendingFollowUp && vm.followUpQuestion == nil) {
                    if vm.answers.count >= 3 {
                        goEnd = true
                        break
                    }
                }
            }
        }
        .navigationDestination(isPresented: $goFollowUp) {
            AnswerInputScreen(vm: vm, isOpenQuestion: false)
        }
        .navigationDestination(isPresented: $goEnd) {
            DomainEndScreen(vm: vm)
        }
    }
}

// ─── 화면 7: 영역 종료 ────────────────────────────────────

public struct DomainEndScreen: View {
    @ObservedObject var vm: InterviewViewModel
    @Environment(\.dismiss) private var dismiss

    public init(vm: InterviewViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GySpace.lg) {
            Spacer()
            Text("영역 0\(vm.domain.indexNumber) — \(vm.domain.labelKo)")
                .font(GyType.caption).foregroundColor(.gyTextTertiary)
            Text("답변이 끝났습니다.")
                .font(GyType.headlineLG).foregroundColor(.gyText)
            Text("분석은 6영역이 모두 끝난 후 한 번에 정리되어 보여드립니다.")
                .font(GyType.bodyMD).foregroundColor(.gyTextSecondary).lineSpacing(4)

            Spacer()
            if let next = nextDomain() {
                Text("다음 영역")
                    .font(GyType.caption).foregroundColor(.gyTextTertiary)
                Text("영역 0\(next.indexNumber) — \(next.labelKo)")
                    .font(GyType.headlineMD).foregroundColor(.gyText)
            }
            Spacer().frame(height: GySpace.lg)
            PrimaryButton(nextDomain() != nil ? "다음 영역으로" : "분석 시작") {
                Task {
                    await vm.finalizeDomain()
                    dismiss()
                }
            }
            SecondaryButton("잠시 쉬었다 할게요") {
                Task {
                    await vm.finalizeDomain()
                    dismiss()
                }
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, GySpace.lg)
        .background(Color.gyBg.ignoresSafeArea())
        .gyNavigationBarHidden()
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
