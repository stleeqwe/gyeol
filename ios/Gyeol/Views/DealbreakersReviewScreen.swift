// 결 (Gyeol) — 프로필("나") → Dealbreaker 다시 보기
// DealbreakersScreen와 같은 아코디언 레이아웃을 재사용하지만, 흐름을 advance하지 않고
// 저장 후 dismiss. 서버는 submit-dealbreakers를 idempotent하게 처리함.

import SwiftUI
import GyeolCore
import GyeolDomain

public struct DealbreakersReviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var texts: [DomainID: String] = [:]
    @State private var expanded: [DomainID: Bool] = [:]
    @State private var isSaving: Bool = false
    @State private var savedOK: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gyeolMD) {
                Spacer().frame(height: .gyeolLG)
                Text("Dealbreaker 다시 보기")
                    .font(Font.gyeolTitle1).foregroundColor(.gyeolTextPrimary).lineSpacing(8)
                Text("내용을 새로 적어 저장하면 그 영역의 기존 입력은 대체됩니다. 비워두면 변경되지 않습니다.")
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
        .navigationTitle("Dealbreaker")
        .gyNavigationBarTitleDisplayModeInline()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(isSaving ? "저장 중..." : "저장", isEnabled: !isSaving && hasAnyInput) {
                Task { await save() }
            }.padding(.bottom, .gyeolMD)
        }
        .gyTrackAppear("DealbreakersReviewScreen")
        .alert("저장되었습니다.", isPresented: $savedOK) {
            Button("확인") { dismiss() }
        }
    }

    private var hasAnyInput: Bool {
        texts.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func textBinding(for d: DomainID) -> Binding<String> {
        Binding(
            get: { texts[d] ?? "" },
            set: { texts[d] = $0 }
        )
    }

    private func expandedBinding(for d: DomainID) -> Binding<Bool> {
        Binding(
            get: { expanded[d] ?? false },
            set: { expanded[d] = $0 }
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            for d in DomainID.allCases {
                let raw = texts[d] ?? ""
                let lines = raw.split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !lines.isEmpty {
                    try await InterviewService.shared.submitDealbreakers(domain: d, rawTexts: lines)
                }
            }
            savedOK = true
        } catch {
            errorMessage = error.localizedDescription
            GyLog.ui.error("dealbreakers_review.save_failed", error: error)
        }
    }
}
