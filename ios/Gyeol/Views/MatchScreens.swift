// 결 (Gyeol) — 화면 9, 10, 11, 12, 13, Me

import SwiftUI
import GyeolCore
import GyeolDomain

// 단일 화면 + 6영역 아코디언으로 통합 — DealbreakersScreen / DealbreakersReviewScreen 참조.
// 기존 화면 9 (per-도메인 DealbreakerInputScreen)는 hub 흐름과 함께 제거됨.

// ─── 화면 10: 본인 검토 (발행 직전 / 프로필 다시 보기) ──

public struct SelfReviewScreen: View {
    @EnvironmentObject private var auth: AuthService
    @State private var analyses: [DomainAnalysis] = []
    @State private var core: CoreIdentity?
    @State private var isLoading: Bool = true
    @State private var publishing: Bool = false
    @State private var publishedOK: Bool = false
    @State private var errorMessage: String?
    private let isReviewOnly: Bool

    public init(isReviewOnly: Bool = false) {
        self.isReviewOnly = isReviewOnly
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolLG) {
                Spacer().frame(height: .gyeolLG)
                Text(isReviewOnly ? "내 답변 다시 보기" : "발행 직전 본인 검토")
                    .gyeolStyle(.title1)
                    .foregroundColor(.gyeolTextPrimary)
                if isReviewOnly {
                    Text("이미 발행됨 — 검토 전용입니다.")
                        .gyeolStyle(.caption2)
                        .foregroundColor(.gyeolTextTertiary)
                }
                if isLoading {
                    HStack(spacing: .gyeolSM) {
                        LoadingDots()
                        Text("검토 자료를 준비하고 있습니다.")
                            .gyeolStyle(.body)
                            .foregroundColor(.gyeolTextSecondary)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .gyeolStyle(.caption2)
                        .foregroundColor(.red)
                }
                if let c = core {
                    VStack(alignment: .leading, spacing: .gyeolSM) {
                        Text("통합 핵심 유형")
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextTertiary)
                        Text(c.label)
                            .gyeolStyle(.display)
                            .foregroundColor(.gyeolTextPrimary)
                        Text(c.interpretation)
                            .gyeolStyle(.body)
                            .foregroundColor(.gyeolTextSecondary)
                    }
                    .padding(.gyeolLG)
                    .background(Color.gyeolBgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous)
                            .stroke(Color.gyeolBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.lg, style: .continuous))
                }

                Text("영역별 결")
                    .gyeolStyle(.caption2)
                    .foregroundColor(.gyeolTextTertiary)
                ForEach(analyses) { a in
                    DomainCard(
                        domain: a.domain,
                        summary: a.summary.where,
                        metaText: a.isFromSkip ? "이 영역은 답변하지 않았습니다." : (a.isFromPrivateKept ? "이 영역은 비공개로 보관됨." : nil),
                        isExpanded: .constant(false)
                    ) {
                        VStack(alignment: .leading, spacing: .gyeolSM) {
                            Text(a.summary.why).gyeolStyle(.body).foregroundColor(.gyeolTextSecondary)
                            Text(a.summary.how).gyeolStyle(.body).foregroundColor(.gyeolTextSecondary)
                            if let t = a.summary.tensionText {
                                Text("긴장: \(t)").gyeolStyle(.caption1).foregroundColor(.gyeolLabelCareful)
                            }
                        }
                    }
                }

                Spacer().frame(height: .gyeolLG)
            }
            .padding(.horizontal, .gyeolLG)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if !isReviewOnly {
                PrimaryButton(publishing ? "발행 중..." : "이대로 발행하기", isEnabled: !publishing && !analyses.isEmpty) {
                    GyLog.ui.info("self_review.publish_tap", fields: [
                        "analyses_count": String(analyses.count),
                        "has_core": String(core != nil),
                    ])
                    GyeolHaptic.medium()
                    Task {
                        publishing = true
                        defer { publishing = false }
                        do {
                            try await InterviewService.shared.publish()
                            publishedOK = true
                            GyeolHaptic.success()
                            // RootView는 auth.publishState 변화로 자동 MainTabView 전환됨.
                            auth.markPublished()
                        } catch {
                            errorMessage = error.localizedDescription
                            GyeolHaptic.error()
                            GyLog.interview.error("publish.failed", error: error)
                        }
                    }
                }
                .padding(.bottom, .gyeolMD)
            }
        }
        .gyTrackAppear("SelfReviewScreen", fields: ["mode": isReviewOnly ? "review_only" : "publish"])
        .task { await load() }
        .alert("발행이 진행 중입니다.", isPresented: $publishedOK) {
            Button("확인") {}
        } message: {
            Text("매칭 후보가 준비되면 알림을 받습니다.")
        }
    }

    private func load() async {
        let start = CFAbsoluteTimeGetCurrent()
        GyLog.interview.info("self_review.load.start")
        do {
            try await InterviewService.shared.prepareReview()
            async let a = InterviewService.shared.loadOwnAnalyses()
            async let c = InterviewService.shared.loadOwnCoreIdentity()
            self.analyses = try await a
            self.core = try await c
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            GyLog.interview.info("self_review.load.ok", fields: [
                "analyses_count": String(self.analyses.count),
                "has_core": String(self.core != nil),
                "duration_ms": String(ms),
            ])
        } catch {
            errorMessage = error.localizedDescription
            GyLog.interview.error("self_review.load.fail", error: error)
        }
        self.isLoading = false
    }
}

// ─── 화면 11: 매칭 후보 목록 ────────────────────────────

public struct MatchListScreen: View {
    @StateObject private var service = MatchService.shared

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: .gyeolMD) {
                ForEach(service.matches) { m in
                    NavigationLink(value: m.id) {
                        CandidateCard(
                            label: m.qualitativeLabel,
                            headline: m.recommendationNarrative?.headline ?? "결을 함께 살펴볼 사람",
                            coreInterpretation: m.recommendationNarrative?.alignmentNarrative ?? ""
                        )
                    }.buttonStyle(.plain)
                }
                if service.matches.isEmpty && !service.isLoading {
                    VStack(spacing: .gyeolMD) {
                        Spacer().frame(height: .gyeol2XL)
                        Text("아직 매칭 후보가 준비되지 않았습니다.")
                            .gyeolStyle(.body)
                            .foregroundColor(.gyeolTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.gyeolXL)
                }
                if let err = service.lastError {
                    Text(err)
                        .gyeolStyle(.caption2)
                        .foregroundColor(.red)
                        .padding(.horizontal, .gyeolLG)
                }
            }
            .padding(.horizontal, .gyeolLG)
            .padding(.vertical, .gyeolMD)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("매칭 후보 목록")
        .gyNavigationBarTitleDisplayModeInline()
        .navigationDestination(for: UUID.self) { id in
            MatchDetailScreen(matchId: id)
        }
        .gyTrackAppear("MatchListScreen")
        .task {
            await service.loadInitial()
            await service.subscribeRealtime()
        }
        .onDisappear {
            Task { await service.unsubscribe() }
        }
        .refreshable {
            GyLog.ui.info("match_list.pull_refresh")
            await service.loadInitial()
        }
    }
}

// ─── 화면 12: 후보 카드 펼침 ────────────────────────────

public struct MatchDetailScreen: View {
    public let matchId: UUID
    @StateObject private var service = MatchService.shared
    @State private var match: Match?
    @State private var showInterestSent: Bool = false
    @State private var interestError: String?
    @State private var isSubmittingInterest: Bool = false

    public init(matchId: UUID) {
        self.matchId = matchId
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolLG) {
                if let m = match {
                    HStack(spacing: 6) {
                        Circle().fill(m.qualitativeLabel.gyeolColor).frame(width: 5, height: 5)
                        Text(m.qualitativeLabel.gyeolUppercaseTag)
                            .font(.custom("Pretendard-SemiBold", fixedSize: 11))
                            .kerning(11 * 0.15)
                            .foregroundColor(m.qualitativeLabel.gyeolColor)
                    }
                    Text("통합 핵심 유형")
                        .font(.custom("Pretendard-Medium", fixedSize: 11))
                        .kerning(11 * 0.10)
                        .foregroundColor(.gyeolTextTertiary)
                    Text(m.recommendationNarrative?.headline ?? "")
                        .gyeolStyle(.title1)
                        .foregroundColor(.gyeolTextPrimary)
                    Text(m.recommendationNarrative?.alignmentNarrative ?? "")
                        .gyeolStyle(.body)
                        .foregroundColor(.gyeolTextSecondary)

                    Divider().background(Color.gyeolDivider).padding(.vertical, .gyeolMD)

                    if !(m.recommendationNarrative?.tensionNarrative.isEmpty ?? true) {
                        Text("결의 차이")
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextTertiary)
                        Text(m.recommendationNarrative?.tensionNarrative ?? "")
                            .gyeolStyle(.body)
                            .foregroundColor(.gyeolTextPrimary)
                    }
                }
            }
            .padding(.horizontal, .gyeolLG)
            .padding(.bottom, .gyeol2XL)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyNavigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: gyTopBarTrailing) {
                Menu {
                    Button("관심 없음", role: .destructive) {
                        GyLog.ui.info("match_detail.decline_tap", fields: ["match_id": matchId.short])
                        GyeolHaptic.selection()
                        Task { await submitInterest(false) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("더 보기")
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("관심 있음", isEnabled: !isSubmittingInterest) {
                GyLog.ui.info("match_detail.interest_tap", fields: ["match_id": matchId.short])
                GyeolHaptic.medium()
                Task { await submitInterest(true) }
            }
            .padding(.bottom, .gyeolMD)
        }
        .alert("관심 표시 완료", isPresented: $showInterestSent) { Button("확인") {} }
        .alert("관심 표시 실패", isPresented: Binding(
            get: { interestError != nil },
            set: { if !$0 { interestError = nil } }
        )) {
            Button("확인") { interestError = nil }
        } message: {
            Text(interestError ?? "")
        }
        .gyTrackAppear("MatchDetailScreen", fields: ["match_id": matchId.short])
        .task {
            await service.ensureExplanation(matchId: matchId)
            match = service.matches.first(where: { $0.id == matchId })
            GyLog.match.info("detail.match_resolved", fields: [
                "match_id": matchId.short,
                "found": String(match != nil),
            ])
        }
    }

    private func submitInterest(_ interested: Bool) async {
        guard !isSubmittingInterest else { return }
        isSubmittingInterest = true
        defer { isSubmittingInterest = false }
        do {
            try await service.setInterest(matchId: matchId, interested: interested)
            showInterestSent = interested
            await service.loadInitial()
            match = service.matches.first(where: { $0.id == matchId })
        } catch {
            interestError = error.localizedDescription
            GyLog.match.error("interest.submit_failed", error: error, fields: [
                "match_id": matchId.short,
                "interested": String(interested),
            ])
        }
    }

}

// ─── 화면 13: 대화방 ────────────────────────────────────

public struct ChatRoomsScreen: View {
    @StateObject private var service = ChatService()

    public init() {}

    public var body: some View {
        List(service.rooms) { room in
            NavigationLink(value: room.id) {
                VStack(alignment: .leading, spacing: .gyeolXS) {
                    Text("결이 잘 맞은 사람")
                        .gyeolStyle(.bodyLarge)
                        .foregroundColor(.gyeolTextPrimary)
                    if let dt = room.lastMessageAt {
                        Text(formatRel(dt))
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextTertiary)
                    }
                }
            }
            .listRowBackground(Color.gyeolBgElevated)
        }
        .scrollContentBackground(.hidden)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("대화방")
        .gyNavigationBarTitleDisplayModeInline()
        .navigationDestination(for: UUID.self) { id in ChatRoomScreen(roomId: id) }
        .gyTrackAppear("ChatRoomsScreen")
        .task { await service.loadRooms(); await service.subscribeRooms() }
        .onDisappear {
            Task { await service.unsubscribeRooms() }
        }
    }
}

public struct ChatRoomScreen: View {
    public let roomId: UUID
    @StateObject private var service = ChatService()
    @State private var draft: String = ""
    @State private var sendError: String?
    @State private var isSending: Bool = false

    public init(roomId: UUID) {
        self.roomId = roomId
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: .gyeolXS) {
                        ForEach(service.messages) { msg in
                            ChatBubble(message: msg, isMine: msg.senderId == GyeolClient.shared.currentUserId)
                                .id(msg.id)
                        }
                    }
                }
                .onChange(of: service.messages.count) { _, _ in
                    if let last = service.messages.last {
                        withAnimation(.gyeolMedium) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 12) {
                TextField("메시지 입력", text: $draft, axis: .vertical)
                    .gyeolStyle(.body)
                    .foregroundColor(.gyeolTextPrimary)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color.gyeolBgSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.md))
                Button(action: {
                    let body = draft
                    GyLog.ui.info("chat.send_tap", fields: [
                        "room_id": roomId.short,
                        "chars": String(body.count),
                    ])
                    GyeolHaptic.light()
                    draft = ""
                    Task { await send(body) }
                }) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(.gyeolBgPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.gyeolAccentPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("메시지 전송")
            }
            .padding(.gyeolMD)
            .background(Color.gyeolBgPrimary)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("결이 잘 맞은 사람")
        .gyNavigationBarTitleDisplayModeInline()
        .gyTrackAppear("ChatRoomScreen", fields: ["room_id": roomId.short])
        .task { await service.openRoom(roomId) }
        .onDisappear {
            Task { await service.unsubscribeMessages() }
        }
        .alert("메시지 전송 실패", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("확인") { sendError = nil }
        } message: {
            Text(sendError ?? "")
        }
    }

    private func send(_ body: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await service.send(roomId: roomId, body: body)
        } catch {
            if draft.isEmpty { draft = body }
            sendError = error.localizedDescription
        }
    }
}

// ─── Me 화면 ────────────────────────────────────────────

public struct MeScreen: View {
    @EnvironmentObject var auth: AuthService
    @State private var showRestartComingSoon: Bool = false

    public init() {}

    public var body: some View {
        List {
            Section("내 결") {
                NavigationLink("내 답변 다시 보기") { SelfReviewScreen(isReviewOnly: true) }
                NavigationLink("Dealbreaker 다시 보기") { DealbreakersReviewScreen() }
                Button(action: {
                    GyLog.ui.info("me.restart_domain_tap_disabled")
                    GyeolHaptic.selection()
                    showRestartComingSoon = true
                }) {
                    HStack {
                        Text("영역 다시 답변하기")
                            .foregroundColor(.gyeolTextSecondary)
                        Spacer()
                        Text("준비 중")
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextTertiary)
                    }
                }
            }
            Section {
                NavigationLink("처리 동의 내역") { ConsentHistoryScreen() }
                NavigationLink("Open Source Licenses") { AcknowledgmentsScreen() }
                NavigationLink("계정 삭제") { AccountDeletionScreen() }
            }
            Section {
                Button("로그아웃") {
                    GyLog.ui.info("me.sign_out_tap")
                    Task { await auth.signOut() }
                }
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("나")
        .gyNavigationBarTitleDisplayModeInline()
        .scrollContentBackground(.hidden)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyTrackAppear("MeScreen")
        .alert("준비 중", isPresented: $showRestartComingSoon) {
            Button("확인") {}
        } message: {
            Text("이 기능은 곧 제공됩니다. 답변을 다시 정리하고 싶다면 잠시만 기다려주세요.")
        }
    }
}

public struct ConsentHistoryScreen: View {
    @EnvironmentObject var auth: AuthService
    @State private var records: [ConsentRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        List {
            if isLoading {
                LoadingDots()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.gyeolBgPrimary)
            } else if records.isEmpty {
                Text("처리 동의 내역이 없습니다.")
                    .gyeolStyle(.body)
                    .foregroundColor(.gyeolTextSecondary)
                    .listRowBackground(Color.gyeolBgPrimary)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(record.consentTextVersion)
                                .gyeolStyle(.bodyLarge)
                                .foregroundColor(.gyeolTextPrimary)
                            Spacer()
                            Text(record.revokedAt == nil ? "활성" : "철회됨")
                                .gyeolStyle(.caption2)
                                .foregroundColor(record.revokedAt == nil ? .gyeolTextPrimary : .gyeolTextTertiary)
                        }
                        Text(formatDate(record.consentedAt))
                            .gyeolStyle(.caption2)
                            .foregroundColor(.gyeolTextSecondary)
                        VStack(alignment: .leading, spacing: .gyeolXS) {
                            consentLine("민감정보 처리", record.sensitiveDataProcessing)
                            consentLine("음성 on-device 처리", record.voiceOnDeviceDisclosed)
                            consentLine("Raw quote 격리", record.rawQuoteIsolationDisclosed)
                            consentLine("AI 학습 미사용", record.noAiTrainingDisclosed)
                            consentLine("한국 데이터 거주", record.dataResidencyDisclosed)
                        }
                    }
                    .padding(.vertical, .gyeolSM)
                    .listRowBackground(Color.gyeolBgElevated)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("처리 동의 내역")
        .gyNavigationBarTitleDisplayModeInline()
        .gyTrackAppear("ConsentHistoryScreen")
        .task { await load() }
        .alert("동의 내역 로드 실패", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            records = try await auth.loadConsentHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func consentLine(_ title: String, _ enabled: Bool) -> some View {
        HStack(spacing: .gyeolSM) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .gyeolTextPrimary : .gyeolTextTertiary)
            Text(title)
                .gyeolStyle(.caption2)
                .foregroundColor(.gyeolTextSecondary)
        }
    }
}

public struct AccountDeletionScreen: View {
    @EnvironmentObject var auth: AuthService
    @State private var showConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: .gyeolLG) {
            Text("계정을 삭제하면 프로필이 매칭에서 제외되고, 삭제 예정일이 기록됩니다.")
                .gyeolStyle(.bodyLarge)
                .foregroundColor(.gyeolTextPrimary)
            Text("삭제 예약 후에는 즉시 로그아웃됩니다. 데이터는 운영 보존 정책에 따라 30일 뒤 purge 대상이 됩니다.")
                .gyeolStyle(.body)
                .foregroundColor(.gyeolTextSecondary)
            Spacer()
            PrimaryButton("계정 삭제", isEnabled: !isDeleting) {
                GyLog.ui.info("account_deletion.confirm_open")
                GyeolHaptic.error()
                showConfirm = true
            }
        }
        .padding(.gyeolLG)
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .navigationTitle("계정 삭제")
        .gyNavigationBarTitleDisplayModeInline()
        .gyTrackAppear("AccountDeletionScreen")
        .confirmationDialog("계정을 삭제할까요?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("계정 삭제", role: .destructive) {
                GyLog.ui.info("account_deletion.confirm_tap")
                Task { await deleteAccount() }
            }
            Button("취소", role: .cancel) {}
        }
        .alert("계정 삭제 실패", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await auth.softDeleteAccount()
        } catch {
            errorMessage = error.localizedDescription
            GyLog.auth.error("account_deletion.failed", error: error)
        }
    }
}

private func formatRel(_ d: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "ko_KR")
    return f.localizedString(for: d, relativeTo: .now)
}

private func formatDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: d)
}
