// 결 (Gyeol) — Domain models (Codable)
// AI프롬프트 v7 §1.4 + 매칭알고리즘 v7 §4 + Edge Functions _shared/types.ts와 정합.

import Foundation

public enum DomainID: String, Codable, CaseIterable, Hashable {
    case belief, society, bioethics, family, work_life, intimacy

    public var labelKo: String {
        switch self {
        case .belief: return "신념 체계"
        case .society: return "사회와 개인"
        case .bioethics: return "생명 윤리"
        case .family: return "가족과 권위"
        case .work_life: return "일과 삶"
        case .intimacy: return "친밀함"
        }
    }

    public var indexNumber: Int {
        switch self {
        case .belief: return 1
        case .society: return 2
        case .bioethics: return 3
        case .family: return 4
        case .work_life: return 5
        case .intimacy: return 6
        }
    }
}

public enum InterviewStatus: String, Codable {
    case in_progress, analyzing, finalized, skipped, private_kept
}

public enum SkipReason: String, Codable, CaseIterable {
    case do_not_want_public
    case not_settled
    case not_important
    case other

    public var labelKo: String {
        switch self {
        case .do_not_want_public: return "공개하고 싶지 않음"
        case .not_settled: return "아직 정리되지 않음"
        case .not_important: return "중요하지 않다고 판단"
        case .other: return "기타"
        }
    }
}

public enum QualitativeLabel: String, Codable {
    case alignment, compromise, boundary

    public var labelKo: String {
        switch self {
        case .alignment: return "결이 잘 맞음"
        case .compromise: return "타협 가능"
        case .boundary: return "경계 확인"
        }
    }
}

public enum AlignmentLevel: String, Codable {
    case strong, moderate, tension, soft_conflict
}

public enum QueueReason: String, Codable {
    case top_match, boundary_check
}

public enum RecommendationStatus: String, Codable {
    case pending, ready, needs_review_hidden, fallback_shown
}

public enum MatchInterest: String, Codable {
    case pending, interested, declined
}

public enum Stance: String, Codable {
    case require, support, allow, neutral, avoid, reject
}

public enum Intensity: String, Codable {
    case strong, moderate, mild
}

// ─── Models ─────────────────────────────────────────────────────

public struct Interview: Codable, Identifiable, Hashable {
    public let id: UUID
    public let userId: UUID
    public let domain: DomainID
    public let status: InterviewStatus
    public let skipReasonValue: SkipReason?
    public let isPrivateKept: Bool
    public let voiceInputUsed: Bool
    public let restartedCount: Int
    public let startedAt: Date
    public let finalizedAt: Date?

    public init(id: UUID, userId: UUID, domain: DomainID, status: InterviewStatus, skipReasonValue: SkipReason?, isPrivateKept: Bool, voiceInputUsed: Bool, restartedCount: Int, startedAt: Date, finalizedAt: Date?) {
        self.id = id
        self.userId = userId
        self.domain = domain
        self.status = status
        self.skipReasonValue = skipReasonValue
        self.isPrivateKept = isPrivateKept
        self.voiceInputUsed = voiceInputUsed
        self.restartedCount = restartedCount
        self.startedAt = startedAt
        self.finalizedAt = finalizedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case domain
        case status
        case skipReasonValue = "skip_reason_value"
        case isPrivateKept = "is_private_kept"
        case voiceInputUsed = "voice_input_used"
        case restartedCount = "restarted_count"
        case startedAt = "started_at"
        case finalizedAt = "finalized_at"
    }
}

public struct InterviewAnswer: Codable, Identifiable, Hashable {
    public let id: UUID
    public let interviewId: UUID
    public let domain: DomainID
    public let seq: Int
    public let isOpenQuestionAnswer: Bool
    public let parentAnswerId: UUID?
    public let followUpQuestionText: String?
    public let textPlain: String  // app side: 평문 보유, 전송 시 service-side 암호화
    public let depthLevel: Int

    public init(id: UUID, interviewId: UUID, domain: DomainID, seq: Int, isOpenQuestionAnswer: Bool, parentAnswerId: UUID?, followUpQuestionText: String?, textPlain: String, depthLevel: Int) {
        self.id = id
        self.interviewId = interviewId
        self.domain = domain
        self.seq = seq
        self.isOpenQuestionAnswer = isOpenQuestionAnswer
        self.parentAnswerId = parentAnswerId
        self.followUpQuestionText = followUpQuestionText
        self.textPlain = textPlain
        self.depthLevel = depthLevel
    }

    enum CodingKeys: String, CodingKey {
        case id
        case interviewId = "interview_id"
        case domain
        case seq
        case isOpenQuestionAnswer = "is_open_question_answer"
        case parentAnswerId = "parent_answer_id"
        case followUpQuestionText = "follow_up_question_text"
        case textPlain = "text_plain"
        case depthLevel = "depth_level"
    }
}

public struct AnalysisSummary: Codable, Hashable {
    public let `where`: String
    public let why: String
    public let how: String
    public let tensionType: String?
    public let tensionText: String?

    public init(where summaryWhere: String, why: String, how: String, tensionType: String?, tensionText: String?) {
        self.where = summaryWhere
        self.why = why
        self.how = how
        self.tensionType = tensionType
        self.tensionText = tensionText
    }

    enum CodingKeys: String, CodingKey {
        case `where` = "summary_where"
        case why = "summary_why"
        case how = "summary_how"
        case tensionType = "summary_tension_type"
        case tensionText = "summary_tension_text"
    }
}

public struct DomainAnalysis: Codable, Identifiable, Hashable {
    public let id: UUID
    public let domain: DomainID
    public let summary: AnalysisSummary
    public let isFromSkip: Bool
    public let isFromPrivateKept: Bool

    public init(id: UUID, domain: DomainID, summary: AnalysisSummary, isFromSkip: Bool, isFromPrivateKept: Bool) {
        self.id = id
        self.domain = domain
        self.summary = summary
        self.isFromSkip = isFromSkip
        self.isFromPrivateKept = isFromPrivateKept
    }
}

public struct CoreIdentity: Codable, Hashable {
    public let label: String
    public let interpretation: String

    public init(label: String, interpretation: String) {
        self.label = label
        self.interpretation = interpretation
    }
}

public struct AlignmentByDomain: Codable, Hashable {
    public let domainId: DomainID
    public let alignmentLevel: AlignmentLevel
    public let alignmentSummary: String

    public init(domainId: DomainID, alignmentLevel: AlignmentLevel, alignmentSummary: String) {
        self.domainId = domainId
        self.alignmentLevel = alignmentLevel
        self.alignmentSummary = alignmentSummary
    }

    enum CodingKeys: String, CodingKey {
        case domainId = "domain_id"
        case alignmentLevel = "alignment_level"
        case alignmentSummary = "alignment_summary"
    }
}

public struct CompatibilityAssessmentBasic: Codable, Hashable {
    public let assessmentVersion: String
    public let finalScore: Double
    public let qualitativeLabel: QualitativeLabel
    public let queueReason: QueueReason
    public let alignmentByDomain: [AlignmentByDomain]
    public let sharedSacredTargets: [String]

    public init(assessmentVersion: String, finalScore: Double, qualitativeLabel: QualitativeLabel, queueReason: QueueReason, alignmentByDomain: [AlignmentByDomain], sharedSacredTargets: [String]) {
        self.assessmentVersion = assessmentVersion
        self.finalScore = finalScore
        self.qualitativeLabel = qualitativeLabel
        self.queueReason = queueReason
        self.alignmentByDomain = alignmentByDomain
        self.sharedSacredTargets = sharedSacredTargets
    }

    enum CodingKeys: String, CodingKey {
        case assessmentVersion = "assessment_version"
        case finalScore = "final_score"
        case qualitativeLabel = "qualitative_label"
        case queueReason = "queue_reason"
        case alignmentByDomain = "alignment_by_domain"
        case sharedSacredTargets = "shared_sacred_targets"
    }
}

public struct RecommendationNarrative: Codable, Hashable {
    public let headline: String
    public let alignmentNarrative: String
    public let tensionNarrative: String

    public init(headline: String, alignmentNarrative: String, tensionNarrative: String) {
        self.headline = headline
        self.alignmentNarrative = alignmentNarrative
        self.tensionNarrative = tensionNarrative
    }

    enum CodingKeys: String, CodingKey {
        case headline
        case alignmentNarrative = "alignment_narrative"
        case tensionNarrative = "tension_narrative"
    }
}

public struct Match: Codable, Identifiable, Hashable {
    public let id: UUID
    public let viewerId: UUID
    public let candidateId: UUID
    public let finalScore: Double
    public let qualitativeLabel: QualitativeLabel
    public let recommendationStatus: RecommendationStatus
    public let recommendationNarrative: RecommendationNarrative?
    public let viewerInterest: MatchInterest
    public let candidateInterest: MatchInterest

    public init(id: UUID, viewerId: UUID, candidateId: UUID, finalScore: Double, qualitativeLabel: QualitativeLabel, recommendationStatus: RecommendationStatus, recommendationNarrative: RecommendationNarrative?, viewerInterest: MatchInterest, candidateInterest: MatchInterest) {
        self.id = id
        self.viewerId = viewerId
        self.candidateId = candidateId
        self.finalScore = finalScore
        self.qualitativeLabel = qualitativeLabel
        self.recommendationStatus = recommendationStatus
        self.recommendationNarrative = recommendationNarrative
        self.viewerInterest = viewerInterest
        self.candidateInterest = candidateInterest
    }

    enum CodingKeys: String, CodingKey {
        case id
        case viewerId = "viewer_id"
        case candidateId = "candidate_id"
        case finalScore = "final_score"
        case qualitativeLabel = "qualitative_label"
        case recommendationStatus = "recommendation_status"
        case recommendationNarrative = "recommendation_narrative"
        case viewerInterest = "viewer_interest"
        case candidateInterest = "candidate_interest"
    }
}

public struct ChatRoom: Codable, Identifiable, Hashable {
    public let id: UUID
    public let matchId: UUID
    public let userAID: UUID
    public let userBID: UUID
    public let lastMessageAt: Date?

    public init(id: UUID, matchId: UUID, userAID: UUID, userBID: UUID, lastMessageAt: Date?) {
        self.id = id
        self.matchId = matchId
        self.userAID = userAID
        self.userBID = userBID
        self.lastMessageAt = lastMessageAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case userAID = "user_a_id"
        case userBID = "user_b_id"
        case lastMessageAt = "last_message_at"
    }
}

public struct ChatMessage: Codable, Identifiable, Hashable {
    public let id: UUID
    public let roomId: UUID
    public let senderId: UUID?
    public let isSystem: Bool
    public let body: String
    public let createdAt: Date

    public init(id: UUID, roomId: UUID, senderId: UUID?, isSystem: Bool, body: String, createdAt: Date) {
        self.id = id
        self.roomId = roomId
        self.senderId = senderId
        self.isSystem = isSystem
        self.body = body
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case senderId = "sender_id"
        case isSystem = "is_system"
        case body
        case createdAt = "created_at"
    }
}

public struct ExplicitDealbreaker: Codable, Identifiable, Hashable {
    public let id: UUID
    public let domain: DomainID
    public let seq: Int
    public let rawUserText: String?
    public let canonicalTargetId: String?

    public init(id: UUID, domain: DomainID, seq: Int, rawUserText: String?, canonicalTargetId: String?) {
        self.id = id
        self.domain = domain
        self.seq = seq
        self.rawUserText = rawUserText
        self.canonicalTargetId = canonicalTargetId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case domain
        case seq
        case rawUserText = "raw_user_text"
        case canonicalTargetId = "canonical_target_id"
    }
}

public struct ConsentRecord: Codable, Identifiable, Hashable {
    public let id: UUID
    public let consentedAt: Date
    public let revokedAt: Date?
    public let consentTextVersion: String
    public let sensitiveDataProcessing: Bool
    public let voiceOnDeviceDisclosed: Bool
    public let rawQuoteIsolationDisclosed: Bool
    public let noAiTrainingDisclosed: Bool
    public let dataResidencyDisclosed: Bool

    public init(id: UUID, consentedAt: Date, revokedAt: Date?, consentTextVersion: String, sensitiveDataProcessing: Bool, voiceOnDeviceDisclosed: Bool, rawQuoteIsolationDisclosed: Bool, noAiTrainingDisclosed: Bool, dataResidencyDisclosed: Bool) {
        self.id = id
        self.consentedAt = consentedAt
        self.revokedAt = revokedAt
        self.consentTextVersion = consentTextVersion
        self.sensitiveDataProcessing = sensitiveDataProcessing
        self.voiceOnDeviceDisclosed = voiceOnDeviceDisclosed
        self.rawQuoteIsolationDisclosed = rawQuoteIsolationDisclosed
        self.noAiTrainingDisclosed = noAiTrainingDisclosed
        self.dataResidencyDisclosed = dataResidencyDisclosed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case consentedAt = "consented_at"
        case revokedAt = "revoked_at"
        case consentTextVersion = "consent_text_version"
        case sensitiveDataProcessing = "sensitive_data_processing"
        case voiceOnDeviceDisclosed = "voice_on_device_disclosed"
        case rawQuoteIsolationDisclosed = "raw_quote_isolation_disclosed"
        case noAiTrainingDisclosed = "no_ai_training_disclosed"
        case dataResidencyDisclosed = "data_residency_disclosed"
    }
}

public struct OpenQuestion: Hashable {
    public let domain: DomainID
    public let primary: String
    public let secondary: String?

    public init(domain: DomainID, primary: String, secondary: String?) {
        self.domain = domain
        self.primary = primary
        self.secondary = secondary
    }

    public static let all: [OpenQuestion] = [
        .init(domain: .belief,
              primary: "당신은 죽음 이후에 무언가가 있다고 생각하시나요?",
              secondary: "그 생각이 지금 당신의 일상에 어떻게 영향을 미치고 있나요?"),
        .init(domain: .society,
              primary: "어떤 사람의 어려움이 사회 구조 때문이라고 생각해본 적이 있나요?",
              secondary: "그 사람의 책임은 어디까지라고 생각하시나요?"),
        .init(domain: .bioethics,
              primary: "임신중지 결정의 도덕적 무게를 어디에 두시나요?",
              secondary: "그 무게가 시점에 따라 달라질 수 있나요?"),
        .init(domain: .family,
              primary: "본인의 결혼 결정에서 부모님의 의견은 어떤 무게를 차지하나요?",
              secondary: "어디서 본인이 양보하지 않을 수 있나요?"),
        .init(domain: .work_life,
              primary: "지금의 일과 삶에서 어디에 더 많은 시간을 두고 싶으신가요?",
              secondary: "그 선택이 5년 뒤에도 같을 것이라고 생각하시나요?"),
        .init(domain: .intimacy,
              primary: "신뢰가 깨졌다고 느낀 순간이 있다면 그 핵심은 무엇이었나요?",
              secondary: "그때 회복은 어떻게 가능했거나, 어떻게 가능하지 않았나요?")
    ]
}
