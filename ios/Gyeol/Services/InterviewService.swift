// 결 (Gyeol) — Interview API 래퍼
// Edge Functions: llm-prompt-a, finalize-domain, llm-prompt-d, llm-prompt-e, publish.

import Foundation
import GyeolDomain
import Supabase

@MainActor
public final class InterviewService {
    public static let shared = InterviewService()

    private var client: SupabaseClient { GyeolClient.shared.supabase }

    private init() {}

    // ─── interview row 보장 ─────────────────────────────────

    public func getOrCreateInterview(domain: DomainID) async throws -> Interview {
        guard let userId = GyeolClient.shared.currentUserId else {
            GyLog.interview.warn("get_or_create_interview.no_user", fields: ["domain": domain.rawValue])
            throw URLError(.userAuthenticationRequired)
        }
        return try await GyLog.interview.trace("get_or_create_interview", fields: [
            "user_id": userId.short,
            "domain": domain.rawValue,
        ]) {
            struct Body: Encodable {
                let domain: DomainID
            }
            let row: Interview = try await client.functions.invoke(
                "get-or-create-interview",
                options: .init(body: Body(domain: domain))
            )
            GyLog.interview.info("get_or_create_interview.created", fields: [
                "interview_id": row.id.short,
                "status": row.status.rawValue,
            ])
            return row
        }
    }

    // ─── 답변 저장 → 후속 질문 ────────────────────────────────

    public struct AnswerSubmit: Encodable {
        public let interview_id: UUID
        public let domain: DomainID
        public let seq: Int
        public let is_open_question_answer: Bool
        public let parent_answer_id: UUID?
        public let follow_up_question_text: String?
        public let text_plain: String   // server-side에서 ciphertext로 변환
        public let text_length: Int
        public let depth_level: Int
        public let voice_input_seconds: Int?
    }

    public func submitAnswer(_ payload: AnswerSubmit) async throws -> InterviewAnswer {
        GyLog.trace.traceText("answer.submit.text", text: payload.text_plain, fields: [
            "interview_id": payload.interview_id.short,
            "domain": payload.domain.rawValue,
            "seq": String(payload.seq),
            "is_open_question": String(payload.is_open_question_answer),
            "depth_level": String(payload.depth_level),
        ])
        return try await GyLog.interview.trace("submit_answer", fields: [
            "interview_id": payload.interview_id.short,
            "domain": payload.domain.rawValue,
            "seq": String(payload.seq),
            "is_open_question": String(payload.is_open_question_answer),
            "depth_level": String(payload.depth_level),
            "text_length": String(payload.text_length),
            "voice_used": payload.voice_input_seconds.map { _ in "true" } ?? "false",
        ]) {
            try await client.functions.invoke(
                "submit-answer",
                options: .init(body: payload)
            )
        }
    }

    public func generateFollowUp(interviewId: UUID, domainId: DomainID, parentAnswerId: UUID) async throws -> String {
        let question = try await GyLog.interview.trace("follow_up.request", fields: [
            "interview_id": interviewId.short,
            "domain": domainId.rawValue,
            "parent_answer_id": parentAnswerId.short,
        ]) {
            struct Body: Encodable {
                let interview_id: UUID
                let domain_id: DomainID
                let parent_answer_id: UUID
            }
            struct Reply: Decodable { let follow_up_question: String }
            let resp: Reply = try await client.functions.invoke(
                "llm-prompt-a",
                options: .init(body: Body(interview_id: interviewId, domain_id: domainId, parent_answer_id: parentAnswerId))
            )
            return resp.follow_up_question
        }
        GyLog.trace.traceText("follow_up.question.text", text: question, fields: [
            "interview_id": interviewId.short,
            "domain": domainId.rawValue,
            "parent_answer_id": parentAnswerId.short,
        ])
        return question
    }

    // ─── 영역 종료 → 분석 ─────────────────────────────────────

    public func finalizeDomain(interviewId: UUID, domainId: DomainID) async throws -> AnalysisSummary {
        return try await GyLog.interview.trace("finalize_domain", fields: [
            "interview_id": interviewId.short,
            "domain": domainId.rawValue,
        ]) {
            struct Body: Encodable {
                let interview_id: UUID
                let domain_id: DomainID
            }
            struct Reply: Decodable {
                let summary: AnalysisSummary
            }
            let resp: Reply = try await client.functions.invoke(
                "finalize-domain",
                options: .init(body: Body(interview_id: interviewId, domain_id: domainId))
            )
            return resp.summary
        }
    }

    // ─── 회피 옵션 ────────────────────────────────────────────

    public func skipDomain(interviewId: UUID, domain: DomainID, reason: SkipReason) async throws {
        try await GyLog.interview.trace("avoid.skip.submit", fields: [
            "interview_id": interviewId.short,
            "domain": domain.rawValue,
            "reason": reason.rawValue,
        ]) {
            struct Body: Encodable {
                let interview_id: UUID
                let domain_id: DomainID
                let action: String
                let skip_reason: SkipReason?
            }
            try await client.functions.invoke(
                "set-domain-status",
                options: .init(body: Body(
                    interview_id: interviewId,
                    domain_id: domain,
                    action: "skip",
                    skip_reason: reason
                ))
            )
        }
    }

    public func keepPrivate(interviewId: UUID, domain: DomainID) async throws {
        try await GyLog.interview.trace("avoid.keep_private.submit", fields: [
            "interview_id": interviewId.short,
            "domain": domain.rawValue,
        ]) {
            struct Body: Encodable {
                let interview_id: UUID
                let domain_id: DomainID
                let action: String
                let skip_reason: SkipReason?
            }
            try await client.functions.invoke(
                "set-domain-status",
                options: .init(body: Body(
                    interview_id: interviewId,
                    domain_id: domain,
                    action: "private",
                    skip_reason: nil
                ))
            )
        }
    }

    // ─── 통합 핵심 + dealbreaker ──────────────────────────────

    public func generateCoreIdentity() async throws -> CoreIdentity {
        return try await GyLog.interview.trace("core_identity.generate") {
            struct Empty: Encodable {}
            struct Reply: Decodable { let core_identity: CoreIdentity }
            let resp: Reply = try await client.functions.invoke(
                "llm-prompt-d",
                options: .init(body: Empty())
            )
            return resp.core_identity
        }
    }

    public func normalizeDealbreakers() async throws {
        try await GyLog.interview.trace("dealbreaker.normalize") {
            struct Empty: Encodable {}
            try await client.functions.invoke("llm-prompt-e", options: .init(body: Empty()))
        }
    }

    public func submitDealbreakers(domain: DomainID, rawTexts: [String]) async throws {
        try await GyLog.interview.trace("dealbreaker.submit", fields: [
            "domain": domain.rawValue,
            "count": String(rawTexts.count),
        ]) {
            struct Body: Encodable {
                let domain: DomainID
                let raw_texts: [String]
            }
            try await client.functions.invoke(
                "submit-dealbreakers",
                options: .init(body: Body(domain: domain, raw_texts: rawTexts))
            )
        }
    }

    public func prepareReview() async throws {
        try await GyLog.interview.trace("review.prepare") {
            struct Empty: Encodable {}
            try await client.functions.invoke("prepare-review", options: .init(body: Empty()))
        }
    }

    // ─── 발행 ────────────────────────────────────────────────

    public func publish() async throws {
        try await GyLog.interview.trace("publish") {
            struct Empty: Encodable {}
            try await client.functions.invoke("publish", options: .init(body: Empty()))
        }
    }

    // ─── 본인 검토 화면 — 영역 분석 로드 ───────────────────────

    public func loadOwnAnalyses() async throws -> [DomainAnalysis] {
        guard let userId = GyeolClient.shared.currentUserId else {
            GyLog.interview.warn("load_own_analyses.no_user")
            return []
        }
        return try await GyLog.interview.trace("load_own_analyses", fields: ["user_id": userId.short]) {
            struct Row: Decodable {
                let id: UUID
                let domain: DomainID
                let summary_where: String
                let summary_why: String
                let summary_how: String
                let summary_tension_type: String?
                let summary_tension_text: String?
                let is_from_skip: Bool
                let is_from_private_kept: Bool
            }
            let rows: [Row] = try await client.from("analyses")
                .select("""
                    id,
                    domain,
                    summary_where,
                    summary_why,
                    summary_how,
                    summary_tension_type,
                    summary_tension_text,
                    is_from_skip,
                    is_from_private_kept
                    """)
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            GyLog.interview.info("load_own_analyses.result", fields: ["count": String(rows.count)])
            return rows.map { r in
                DomainAnalysis(
                    id: r.id,
                    domain: r.domain,
                    summary: AnalysisSummary(
                        where: r.summary_where,
                        why: r.summary_why,
                        how: r.summary_how,
                        tensionType: r.summary_tension_type,
                        tensionText: r.summary_tension_text
                    ),
                    isFromSkip: r.is_from_skip,
                    isFromPrivateKept: r.is_from_private_kept
                )
            }
        }
    }

    // ─── Sequential flow — interviews aggregate + publish state ────

    public func loadOwnInterviews() async throws -> [Interview] {
        guard let userId = GyeolClient.shared.currentUserId else {
            GyLog.interview.warn("load_own_interviews.no_user")
            return []
        }
        return try await GyLog.interview.trace("load_own_interviews", fields: ["user_id": userId.short]) {
            let rows: [Interview] = try await client.from("interviews")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            GyLog.interview.info("load_own_interviews.result", fields: ["count": String(rows.count)])
            return rows
        }
    }

    /// Derives the resume cursor from server interview rows (no `published_at` column exists,
    /// and `core_identity` is created during `prepare-review` *before* publish click — so it is
    /// not a reliable publish signal). The "published" flag is tracked locally via
    /// `AuthService.markPublished()` after a successful publish() call.
    /// Returns the cursor that should drive `InterviewShellView` when the user is unpublished.
    public func computeResumeCursor() async throws -> ResumeCursor {
        let interviews = try await loadOwnInterviews()
        if interviews.isEmpty {
            return .fresh
        }
        let byDomain = Dictionary(uniqueKeysWithValues: interviews.map { ($0.domain, $0) })
        for d in DomainID.allCases {
            guard let iv = byDomain[d] else {
                return .domainIntro(d)
            }
            switch iv.status {
            case .finalized, .skipped, .private_kept:
                continue
            case .in_progress, .analyzing:
                return .domainInProgress(d)
            }
        }
        return .dealbreakers
    }

    public func loadOwnCoreIdentity() async throws -> CoreIdentity? {
        guard let userId = GyeolClient.shared.currentUserId else {
            GyLog.interview.warn("load_own_core_identity.no_user")
            return nil
        }
        return try await GyLog.interview.trace("load_own_core_identity", fields: ["user_id": userId.short]) {
            struct Row: Decodable { let label: String; let interpretation: String }
            let rows: [Row] = try await client.from("core_identities")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            GyLog.interview.info("load_own_core_identity.result", fields: ["found": String(!rows.isEmpty)])
            return rows.first.map { CoreIdentity(label: $0.label, interpretation: $0.interpretation) }
        }
    }
}
