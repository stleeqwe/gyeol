// 결 (Gyeol) — Interview ViewModel
// 화면 3-7 + 화면 4-A·B·C + 화면 9 + 화면 10 흐름.

import Foundation
import GyeolDomain
import SwiftUI

@MainActor
public final class InterviewViewModel: ObservableObject {
    @Published public var domain: DomainID
    @Published public var openQuestion: OpenQuestion
    @Published public var interview: Interview?

    @Published public var answers: [InterviewAnswer] = []
    @Published public var currentDraft: String = ""
    @Published public var currentDepth: Int = 1
    @Published public var followUpQuestion: String?
    @Published public var pendingFollowUp: Bool = false
    @Published public var isAnalyzing: Bool = false
    @Published public var isFinalized: Bool = false
    @Published public var errorMessage: String?

    public init(domain: DomainID) {
        self.domain = domain
        self.openQuestion = OpenQuestion.all.first(where: { $0.domain == domain }) ?? OpenQuestion.all[0]
    }

    public func bootstrap() async {
        do {
            let row = try await InterviewService.shared.getOrCreateInterview(domain: domain)
            self.interview = row
            self.isFinalized = row.status == .finalized
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func submitOpenAnswer(voiceInputSeconds: Int? = nil) async {
        guard let interview, !currentDraft.isEmpty else { return }
        let plain = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return }
        let payload = InterviewService.AnswerSubmit(
            interview_id: interview.id,
            domain: domain,
            seq: nextSeq(),
            is_open_question_answer: true,
            parent_answer_id: nil,
            follow_up_question_text: nil,
            text_plain: plain,
            text_length: plain.count,
            depth_level: currentDepth,
            voice_input_seconds: voiceInputSeconds
        )
        await submit(payload: payload)
    }

    public func submitFollowUpAnswer(voiceInputSeconds: Int? = nil) async {
        guard let interview, !currentDraft.isEmpty, let parent = answers.last else { return }
        let plain = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return }
        let payload = InterviewService.AnswerSubmit(
            interview_id: interview.id,
            domain: domain,
            seq: nextSeq(),
            is_open_question_answer: false,
            parent_answer_id: parent.id,
            follow_up_question_text: followUpQuestion,
            text_plain: plain,
            text_length: plain.count,
            depth_level: currentDepth,
            voice_input_seconds: voiceInputSeconds
        )
        await submit(payload: payload)
    }

    private func submit(payload: InterviewService.AnswerSubmit) async {
        do {
            let saved = try await InterviewService.shared.submitAnswer(payload)
            self.answers.append(saved)
            self.currentDraft = ""
            await generateFollowUp(for: saved)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func generateFollowUp(for answer: InterviewAnswer) async {
        guard let interview, answers.count < 5 else { return }   // 영역당 최대 4-5 답변
        self.pendingFollowUp = true
        defer { self.pendingFollowUp = false }
        do {
            let q = try await InterviewService.shared.generateFollowUp(
                interviewId: interview.id,
                domainId: domain,
                parentAnswerId: answer.id
            )
            self.followUpQuestion = q
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func easierMode() {
        if currentDepth < 3 {
            currentDepth += 1
            GyLog.interview.info("depth.increased", fields: [
                "domain": domain.rawValue,
                "new_depth": String(currentDepth),
            ])
        }
    }

    public func skip(reason: SkipReason) async {
        guard let interview else { return }
        GyLog.interview.info("avoid.skip", fields: [
            "domain": domain.rawValue,
            "reason": reason.rawValue,
        ])
        do {
            try await InterviewService.shared.skipDomain(interviewId: interview.id, domain: domain, reason: reason)
            self.isFinalized = true
        } catch {
            self.errorMessage = error.localizedDescription
            GyLog.interview.error("avoid.skip_failed", error: error)
        }
    }

    public func keepPrivate() async {
        guard let interview else { return }
        GyLog.interview.info("avoid.keep_private", fields: ["domain": domain.rawValue])
        do {
            try await InterviewService.shared.keepPrivate(interviewId: interview.id, domain: domain)
            self.isFinalized = true
        } catch {
            self.errorMessage = error.localizedDescription
            GyLog.interview.error("avoid.keep_private_failed", error: error)
        }
    }

    public func finalizeDomain() async {
        guard let interview else { return }
        self.isAnalyzing = true
        defer { self.isAnalyzing = false }
        do {
            _ = try await InterviewService.shared.finalizeDomain(
                interviewId: interview.id,
                domainId: domain
            )
            self.isFinalized = true
            GyLog.interview.info("domain.finalized", fields: [
                "domain": domain.rawValue,
                "answer_count": String(answers.count),
            ])
        } catch {
            self.errorMessage = error.localizedDescription
            GyLog.interview.error("domain.finalize_failed", error: error, fields: ["domain": domain.rawValue])
        }
    }

    private func nextSeq() -> Int {
        (answers.map { $0.seq }.max() ?? 0) + 1
    }
}
