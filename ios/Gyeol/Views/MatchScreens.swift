// 결 (Gyeol) — 화면 9, 10, 11, 12, 13, Me

import SwiftUI
import GyeolCore
import GyeolDomain

// ─── 화면 9: 명시 Dealbreaker 입력 ──────────────────────

public struct DealbreakerInputScreen: View {
    @Environment(\.dismiss) private var dismiss
    public let domain: DomainID
    @State private var text: String = ""
    @State private var showExamples: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public init(domain: DomainID) {
        self.domain = domain
    }

    private var examples: [String] {
        switch domain {
        case .belief:
            return ["강한 종교적 신앙이 삶의 중심인 사람", "결혼 시 개종을 요구하는 사람", "자녀 종교 교육을 강요하는 사람"]
        case .society:
            return ["개인 책임만을 강조하며 구조적 불평등을 부정하는 사람", "특정 집단에 대한 강한 편견을 가진 사람"]
        case .bioethics:
            return ["임신중지를 절대 허용하지 않는 사람", "신체 자기결정권을 부정하는 사람"]
        case .family:
            return ["부모 의견에 본인 결정을 완전히 종속시키는 사람", "결혼 시 자녀를 반드시 가져야 한다고 강요하는 사람"]
        case .work_life:
            return ["관계 시간을 야망에 항상 양보시키는 사람"]
        case .intimacy:
            return ["불륜·외도 경험을 가벼이 보는 사람", "물리적·언어적 폭력 사용 사람"]
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GySpace.lg) {
                Spacer().frame(height: GySpace.xs)
                Text("영역 0\(domain.indexNumber)")
                    .font(GyType.caption).foregroundColor(.gyTextTertiary)
                Text(domain.labelKo)
                    .font(GyType.headlineMD).foregroundColor(.gyText)
                Text("이 영역에서 절대 만날 수 없는 결의 사람이 있다면 적어주세요.")
                    .font(GyType.bodyMD).foregroundColor(.gyTextSecondary).lineSpacing(4)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("자유롭게 적어주세요. 빈 칸으로 두셔도 됩니다.")
                            .font(GyType.bodyLG).foregroundColor(.gyTextDisabled)
                            .padding(GySpace.md)
                    }
                    TextEditor(text: $text)
                        .font(GyType.bodyLG).foregroundColor(.gyText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(GySpace.xs)
                }
                .background(Color.gyBgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: GyRadius.md))

                DisclosureGroup(isExpanded: $showExamples) {
                    VStack(alignment: .leading, spacing: GySpace.xs) {
                        ForEach(examples, id: \.self) { e in
                            Text("— \(e)").font(GyType.bodySM).foregroundColor(.gyTextSecondary)
                        }
                    }
                    .padding(.top, GySpace.xs)
                } label: {
                    Text("예시 보기").font(GyType.bodySM).foregroundColor(.gyTextSecondary)
                }
                .accentColor(.gyTextSecondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(GyType.bodySM)
                        .foregroundColor(.red)
                }

                Spacer().frame(height: GySpace.xl)
            }
            .padding(.horizontal, GySpace.lg)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: GySpace.xs) {
                Button("이 영역은 비워둘게요") {
                    Task { await save(rawTexts: []) }
                }
                    .font(GyType.bodySM).foregroundColor(.gyTextSecondary)
                    .disabled(isSaving)
                PrimaryButton(isSaving ? "저장 중..." : "다음 영역으로", isEnabled: !isSaving) {
                    Task { await save(rawTexts: normalizedInputs()) }
                }
                    .padding(.bottom, GySpace.md)
            }
        }
    }

    private func normalizedInputs() -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save(rawTexts: [String]) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await InterviewService.shared.submitDealbreakers(domain: domain, rawTexts: rawTexts)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ─── 화면 10: 본인 검토 (발행 직전) ─────────────────────

public struct SelfReviewScreen: View {
    @State private var analyses: [DomainAnalysis] = []
    @State private var core: CoreIdentity?
    @State private var isLoading: Bool = true
    @State private var publishing: Bool = false
    @State private var publishedOK: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GySpace.lg) {
                Spacer().frame(height: GySpace.lg)
                Text("발행 직전 본인 검토")
                    .font(GyType.headlineLG).foregroundColor(.gyText)
                if isLoading {
                    Text("검토 자료를 준비하고 있습니다.")
                        .font(GyType.bodyMD)
                        .foregroundColor(.gyTextSecondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(GyType.bodySM)
                        .foregroundColor(.red)
                }
                if let c = core {
                    VStack(alignment: .leading, spacing: GySpace.xs) {
                        Text("통합 핵심 유형").font(GyType.caption).foregroundColor(.gyTextTertiary)
                        Text(c.label).font(GyType.headlineMD).foregroundColor(.gyText)
                        Text(c.interpretation).font(GyType.bodyMD).foregroundColor(.gyTextSecondary).lineSpacing(4)
                    }
                    .padding(GySpace.lg)
                    .background(Color.gyBgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: GyRadius.lg))
                }

                Text("영역별 결").font(GyType.caption).foregroundColor(.gyTextTertiary)
                ForEach(analyses) { a in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: GySpace.xs) {
                            Text(a.summary.where).font(GyType.bodyMD).foregroundColor(.gyText)
                            Text(a.summary.why).font(GyType.bodyMD).foregroundColor(.gyTextSecondary)
                            Text(a.summary.how).font(GyType.bodyMD).foregroundColor(.gyTextSecondary)
                            if let t = a.summary.tensionText {
                                Text("긴장: \(t)").font(GyType.bodySM).foregroundColor(.gyBoundary)
                            }
                            if a.isFromSkip { Text("이 영역은 답변하지 않았습니다.").font(GyType.bodySM).foregroundColor(.gyTextTertiary) }
                            if a.isFromPrivateKept { Text("이 영역은 비공개로 보관됨.").font(GyType.bodySM).foregroundColor(.gyTextTertiary) }
                        }
                        .padding(.top, GySpace.xs)
                    } label: {
                        VStack(alignment: .leading, spacing: GySpace.xxs) {
                            Text("영역 0\(a.domain.indexNumber)").font(GyType.caption).foregroundColor(.gyTextTertiary)
                            Text(a.domain.labelKo).font(GyType.headlineMD).foregroundColor(.gyText)
                            if !a.summary.where.isEmpty {
                                Text(a.summary.where).font(GyType.bodySM).foregroundColor(.gyTextSecondary)
                            }
                        }
                    }
                    .padding(GySpace.lg)
                    .background(Color.gyBgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: GyRadius.lg))
                }

                Spacer().frame(height: GySpace.lg)
            }
            .padding(.horizontal, GySpace.lg)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(publishing ? "발행 중..." : "이대로 발행하기", isEnabled: !publishing && !analyses.isEmpty) {
                Task {
                    publishing = true
                    defer { publishing = false }
                    do {
                        try await InterviewService.shared.publish()
                        publishedOK = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }.padding(.bottom, GySpace.md)
        }
        .task { await load() }
        .alert("발행이 진행 중입니다.", isPresented: $publishedOK) {
            Button("확인") {}
        } message: {
            Text("매칭 후보가 준비되면 알림을 받습니다.")
        }
    }

    private func load() async {
        do {
            try await InterviewService.shared.prepareReview()
            async let a = InterviewService.shared.loadOwnAnalyses()
            async let c = InterviewService.shared.loadOwnCoreIdentity()
            self.analyses = try await a
            self.core = try await c
        } catch {
            errorMessage = error.localizedDescription
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
            LazyVStack(spacing: GySpace.md) {
                ForEach(service.matches) { m in
                    NavigationLink(value: m.id) {
                        MatchCard(
                            label: m.qualitativeLabel,
                            headline: m.recommendationNarrative?.headline ?? "결을 함께 살펴볼 사람",
                            coreLabel: "통합 핵심 유형",
                            interpretation: m.recommendationNarrative?.alignmentNarrative ?? ""
                        )
                    }.buttonStyle(.plain)
                }
                if service.matches.isEmpty && !service.isLoading {
                    Text("아직 매칭 후보가 준비되지 않았습니다.")
                        .font(GyType.bodyMD).foregroundColor(.gyTextSecondary)
                        .padding(GySpace.xl)
                }
                if let err = service.lastError {
                    Text(err)
                        .font(GyType.bodySM)
                        .foregroundColor(.red)
                        .padding(.horizontal, GySpace.lg)
                }
            }
            .padding(.horizontal, GySpace.lg)
            .padding(.vertical, GySpace.md)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("매칭 후보 목록")
        .gyNavigationBarTitleDisplayModeInline()
        .navigationDestination(for: UUID.self) { id in
            MatchDetailScreen(matchId: id)
        }
        .task {
            await service.loadInitial()
            await service.subscribeRealtime()
        }
        .onDisappear {
            Task { await service.unsubscribe() }
        }
        .refreshable { await service.loadInitial() }
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
            VStack(alignment: .leading, spacing: GySpace.lg) {
                if let m = match {
                    HStack(spacing: GySpace.xs) {
                        Circle().fill(dotColor(m.qualitativeLabel)).frame(width: 8, height: 8)
                        Text(m.qualitativeLabel.labelKo)
                            .font(GyType.labelMD).foregroundColor(.gyTextSecondary)
                    }
                    Text("통합 핵심 유형").font(GyType.caption).foregroundColor(.gyTextTertiary)
                    Text(m.recommendationNarrative?.headline ?? "")
                        .font(GyType.headlineLG).foregroundColor(.gyText).lineSpacing(8)
                    Text(m.recommendationNarrative?.alignmentNarrative ?? "")
                        .font(GyType.bodyLG).foregroundColor(.gyTextSecondary).lineSpacing(6)

                    Divider().background(Color.gyDivider).padding(.vertical, GySpace.md)

                    if !(m.recommendationNarrative?.tensionNarrative.isEmpty ?? true) {
                        Text("결의 차이").font(GyType.caption).foregroundColor(.gyTextTertiary)
                        Text(m.recommendationNarrative?.tensionNarrative ?? "")
                            .font(GyType.bodyLG).foregroundColor(.gyText).lineSpacing(6)
                    }
                }
            }
            .padding(.horizontal, GySpace.lg)
            .padding(.bottom, GySpace.xxl)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .gyNavigationBarTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: gyTopBarTrailing) {
                Menu {
                    Button("관심 없음", role: .destructive) {
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
                Task { await submitInterest(true) }
            }
            .padding(.bottom, GySpace.md)
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
        .task {
            await service.ensureExplanation(matchId: matchId)
            match = service.matches.first(where: { $0.id == matchId })
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
        }
    }

    private func dotColor(_ q: QualitativeLabel) -> Color {
        switch q { case .alignment: return .gyText; case .compromise: return .gyTextSecondary; case .boundary: return .gyBoundary }
    }
}

// ─── 화면 13: 대화방 ────────────────────────────────────

public struct ChatRoomsScreen: View {
    @StateObject private var service = ChatService()

    public init() {}

    public var body: some View {
        List(service.rooms) { room in
            NavigationLink(value: room.id) {
                VStack(alignment: .leading, spacing: GySpace.xxs) {
                    Text("결이 잘 맞은 사람").font(GyType.headlineSM).foregroundColor(.gyText)
                    if let dt = room.lastMessageAt {
                        Text(formatRel(dt)).font(GyType.caption).foregroundColor(.gyTextTertiary)
                    }
                }
            }
            .listRowBackground(Color.gyBgElevated)
        }
        .scrollContentBackground(.hidden)
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("대화방")
        .gyNavigationBarTitleDisplayModeInline()
        .navigationDestination(for: UUID.self) { id in ChatRoomScreen(roomId: id) }
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
                    LazyVStack(spacing: GySpace.xxs) {
                        ForEach(service.messages) { msg in
                            ChatBubble(message: msg, isMine: msg.senderId == GyeolClient.shared.currentUserId)
                                .id(msg.id)
                        }
                    }
                }
                .onChange(of: service.messages.count) { _, _ in
                    if let last = service.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: GySpace.sm) {
                TextField("메시지 입력", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(GySpace.sm)
                    .background(Color.gyBgSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: GyRadius.md))
                Button(action: {
                    let body = draft
                    draft = ""
                    Task { await send(body) }
                }) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(.gyAccentContrast)
                        .frame(width: 36, height: 36)
                        .background(Color.gyAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("메시지 전송")
            }
            .padding(GySpace.md)
            .background(Color.gyBg)
        }
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("결이 잘 맞은 사람")
        .gyNavigationBarTitleDisplayModeInline()
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

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink("처리 동의 내역") { ConsentHistoryScreen() }
                NavigationLink("계정 삭제") { AccountDeletionScreen() }
            }
            Section {
                Button("로그아웃") { Task { await auth.signOut() } }
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("나")
        .gyNavigationBarTitleDisplayModeInline()
        .scrollContentBackground(.hidden)
        .background(Color.gyBg.ignoresSafeArea())
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
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.gyBg)
            } else if records.isEmpty {
                Text("처리 동의 내역이 없습니다.")
                    .font(GyType.bodyMD)
                    .foregroundColor(.gyTextSecondary)
                    .listRowBackground(Color.gyBg)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: GySpace.sm) {
                        HStack {
                            Text(record.consentTextVersion)
                                .font(GyType.headlineSM)
                                .foregroundColor(.gyText)
                            Spacer()
                            Text(record.revokedAt == nil ? "활성" : "철회됨")
                                .font(GyType.caption)
                                .foregroundColor(record.revokedAt == nil ? .gyText : .gyTextTertiary)
                        }
                        Text(formatDate(record.consentedAt))
                            .font(GyType.bodySM)
                            .foregroundColor(.gyTextSecondary)
                        VStack(alignment: .leading, spacing: GySpace.xxs) {
                            consentLine("민감정보 처리", record.sensitiveDataProcessing)
                            consentLine("음성 on-device 처리", record.voiceOnDeviceDisclosed)
                            consentLine("Raw quote 격리", record.rawQuoteIsolationDisclosed)
                            consentLine("AI 학습 미사용", record.noAiTrainingDisclosed)
                            consentLine("한국 데이터 거주", record.dataResidencyDisclosed)
                        }
                    }
                    .padding(.vertical, GySpace.xs)
                    .listRowBackground(Color.gyBgElevated)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("처리 동의 내역")
        .gyNavigationBarTitleDisplayModeInline()
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
        HStack(spacing: GySpace.xs) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .gyText : .gyTextTertiary)
            Text(title)
                .font(GyType.bodySM)
                .foregroundColor(.gyTextSecondary)
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
        VStack(alignment: .leading, spacing: GySpace.lg) {
            Text("계정을 삭제하면 프로필이 매칭에서 제외되고, 삭제 예정일이 기록됩니다.")
                .font(GyType.bodyLG)
                .foregroundColor(.gyText)
                .lineSpacing(6)
            Text("삭제 예약 후에는 즉시 로그아웃됩니다. 데이터는 운영 보존 정책에 따라 30일 뒤 purge 대상이 됩니다.")
                .font(GyType.bodyMD)
                .foregroundColor(.gyTextSecondary)
                .lineSpacing(5)
            Spacer()
            PrimaryButton("계정 삭제", isEnabled: !isDeleting) {
                showConfirm = true
            }
        }
        .padding(GySpace.lg)
        .background(Color.gyBg.ignoresSafeArea())
        .navigationTitle("계정 삭제")
        .gyNavigationBarTitleDisplayModeInline()
        .confirmationDialog("계정을 삭제할까요?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("계정 삭제", role: .destructive) {
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
