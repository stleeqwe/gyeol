// 결 (Gyeol) — 화면 9 (재구성): Dealbreaker 단일 화면 + 6영역 아코디언
// 6영역 답변이 모두 끝난 직후, 본인 검토 + 발행 직전 단계.

import SwiftUI
import GyeolCore
import GyeolDomain

public struct DealbreakersScreen: View {
    @EnvironmentObject var coord: InterviewFlowCoordinator
    @State private var texts: [DomainID: String] = [:]
    @State private var expanded: [DomainID: Bool] = [:]
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolMD) {
                Spacer().frame(height: .gyeolLG)
                Text("만나고 싶지 않은 결")
                    .font(Font.gyeolTitle1).foregroundColor(.gyeolTextPrimary).lineSpacing(8)
                Text("각 영역에서 절대 만날 수 없는 결의 사람이 있다면 적어주세요. 영역은 비워두셔도 됩니다.")
                    .font(Font.gyeolBody).foregroundColor(.gyeolTextSecondary).lineSpacing(4)

                Spacer().frame(height: .gyeolMD)

                VStack(spacing: 0) {
                    ForEach(DomainID.allCases, id: \.self) { d in
                        DealbreakerDomainSection(
                            domain: d,
                            text: textBinding(for: d),
                            isExpanded: expandedBinding(for: d)
                        )
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Font.gyeolCaption2)
                        .foregroundColor(.red)
                        .padding(.top, 12)
                }

                Spacer().frame(height: .gyeolXL)
            }
            .padding(.horizontal, .gyeolLG)
        }
        .background(Color.gyeolBgPrimary.ignoresSafeArea())
        .gyPauseToolbar { coord.pause() }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(isSaving ? "저장 중..." : "다음으로", isEnabled: !isSaving) {
                Task { await saveAndAdvance() }
            }.padding(.bottom, .gyeolMD)
        }
        .gyTrackAppear("DealbreakersScreen")
        .onAppear { restoreDrafts() }
    }

    private func textBinding(for d: DomainID) -> Binding<String> {
        Binding(
            get: { texts[d] ?? "" },
            set: { newValue in
                texts[d] = newValue
                DealbreakerDraftStore.save(domain: d, text: newValue)
            }
        )
    }

    private func expandedBinding(for d: DomainID) -> Binding<Bool> {
        Binding(
            get: { expanded[d] ?? false },
            set: { expanded[d] = $0 }
        )
    }

    private func restoreDrafts() {
        for d in DomainID.allCases {
            let draft = DealbreakerDraftStore.load(domain: d) ?? ""
            texts[d] = draft
            // 작성된 영역만 펼쳐 보여줌 — 나머지는 접힘
            expanded[d] = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveAndAdvance() async {
        isSaving = true
        defer { isSaving = false }
        do {
            for d in DomainID.allCases {
                let raw = texts[d] ?? ""
                let lines = raw.split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                try await InterviewService.shared.submitDealbreakers(domain: d, rawTexts: lines)
            }
            DealbreakerDraftStore.clearAll()
            coord.advanceFromDealbreakers()
        } catch {
            errorMessage = error.localizedDescription
            GyLog.ui.error("dealbreakers.save_failed", error: error)
        }
    }
}

// ─── 영역 한 칸 (아코디언) ────────────────────────────────

struct DealbreakerDomainSection: View {
    let domain: DomainID
    @Binding var text: String
    @Binding var isExpanded: Bool
    @State private var showExamples: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(Animation.gyeolFast) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gyeolTextTertiary)
                        .frame(width: 12)
                    Text(domain.labelKo)
                        .font(Font.gyeolCTA)
                        .foregroundColor(.gyeolTextPrimary)
                    Spacer()
                    Text(statusLabel)
                        .font(Font.gyeolCaption2)
                        .foregroundColor(.gyeolTextTertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, .gyeolMD)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("자유롭게 적어주세요. 비워두셔도 됩니다.")
                            .font(Font.gyeolCaption1)
                            .foregroundColor(.gyeolTextTertiary.opacity(0.55))
                            .padding(.gyeolMD)
                    }
                    TextEditor(text: $text)
                        .font(Font.gyeolCaption1)
                        .foregroundColor(.gyeolTextPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(.gyeolSM)
                }
                .background(Color.gyeolBgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.md))

                DisclosureGroup(isExpanded: $showExamples) {
                    VStack(alignment: .leading, spacing: .gyeolSM) {
                        ForEach(examples, id: \.self) { e in
                            Text("— \(e)")
                                .font(Font.gyeolCaption2)
                                .foregroundColor(.gyeolTextSecondary)
                        }
                    }
                    .padding(.top, .gyeolSM)
                } label: {
                    Text("예시 보기").font(Font.gyeolCaption2).foregroundColor(.gyeolTextSecondary)
                }
                .padding(.bottom, 12)
            }

            Divider().background(Color.gyeolDivider)
        }
    }

    private var statusLabel: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "비어있음" : "작성됨"
    }

    private var examples: [String] {
        switch domain {
        case .belief:
            return [
                "강한 종교적 신앙이 삶의 중심인 사람",
                "결혼 시 개종을 요구하는 사람",
                "자녀 종교 교육을 강요하는 사람",
            ]
        case .society:
            return [
                "개인 책임만을 강조하며 구조적 불평등을 부정하는 사람",
                "특정 집단에 대한 강한 편견을 가진 사람",
            ]
        case .bioethics:
            return [
                "임신중지를 절대 허용하지 않는 사람",
                "신체 자기결정권을 부정하는 사람",
            ]
        case .family:
            return [
                "부모 의견에 본인 결정을 완전히 종속시키는 사람",
                "결혼 시 자녀를 반드시 가져야 한다고 강요하는 사람",
            ]
        case .work_life:
            return [
                "관계 시간을 야망에 항상 양보시키는 사람",
            ]
        case .intimacy:
            return [
                "불륜·외도 경험을 가벼이 보는 사람",
                "물리적·언어적 폭력 사용 사람",
            ]
        }
    }
}

// ─── Dealbreaker 임시 저장 (UserDefaults) ──────────────────
// `submit-dealbreakers`로 보낸 raw_user_text는 서버에서 bytea로 암호화되어 저장됨.
// 클라이언트에서 다시 읽어 평문 복원이 불가하므로, 발행 전 작성 중인 초안만 로컬 보관.

enum DealbreakerDraftStore {
    static func load(domain: DomainID) -> String? {
        UserDefaults.standard.string(forKey: key(domain))
    }

    static func save(domain: DomainID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(domain))
        } else {
            UserDefaults.standard.set(text, forKey: key(domain))
        }
    }

    static func clearAll() {
        for d in DomainID.allCases {
            UserDefaults.standard.removeObject(forKey: key(d))
        }
    }

    private static func key(_ d: DomainID) -> String {
        "gyeol.dealbreaker_draft.\(d.rawValue)"
    }
}
