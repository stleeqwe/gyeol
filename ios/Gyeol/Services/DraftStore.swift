// 결 (Gyeol) — 인터뷰 답변 로컬 drafts (offline-first)
// Architecture ADR-012

import Foundation
import GyeolDomain
import SwiftData

@Model
public final class AnswerDraft {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var key: String
    public var domain: String           // DomainID rawValue
    public var seq: Int
    public var isOpenQuestionAnswer: Bool
    public var followUpQuestionText: String?
    public var text: String
    public var depthLevel: Int
    public var voiceInputSeconds: Int?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        domain: String,
        seq: Int,
        isOpenQuestionAnswer: Bool,
        followUpQuestionText: String? = nil,
        text: String,
        depthLevel: Int = 1,
        voiceInputSeconds: Int? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.key = key
        self.domain = domain
        self.seq = seq
        self.isOpenQuestionAnswer = isOpenQuestionAnswer
        self.followUpQuestionText = followUpQuestionText
        self.text = text
        self.depthLevel = depthLevel
        self.voiceInputSeconds = voiceInputSeconds
        self.updatedAt = updatedAt
    }
}

public enum DraftSchema {
    public static let container: ModelContainer = {
        do {
            return try ModelContainer(for: AnswerDraft.self)
        } catch {
            fatalError("Draft container failed: \(error)")
        }
    }()
}

public enum DraftStore {
    public static func makeKey(domain: DomainID, isOpenQuestion: Bool, followUpQuestion: String?) -> String {
        let questionPart = isOpenQuestion ? "open" : (followUpQuestion ?? "follow-up")
        return "\(domain.rawValue)|\(questionPart)"
    }

    @MainActor
    public static func load(context: ModelContext, key: String) -> String? {
        var descriptor = FetchDescriptor<AnswerDraft>(
            predicate: #Predicate { $0.key == key },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.text
    }

    @MainActor
    public static func upsert(
        context: ModelContext,
        key: String,
        domain: DomainID,
        seq: Int,
        isOpenQuestionAnswer: Bool,
        followUpQuestionText: String?,
        text: String,
        depthLevel: Int,
        voiceInputSeconds: Int?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            delete(context: context, key: key)
            return
        }
        var descriptor = FetchDescriptor<AnswerDraft>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.text = text
            existing.seq = seq
            existing.depthLevel = depthLevel
            existing.voiceInputSeconds = voiceInputSeconds
            existing.updatedAt = .now
        } else {
            context.insert(AnswerDraft(
                key: key,
                domain: domain.rawValue,
                seq: seq,
                isOpenQuestionAnswer: isOpenQuestionAnswer,
                followUpQuestionText: followUpQuestionText,
                text: text,
                depthLevel: depthLevel,
                voiceInputSeconds: voiceInputSeconds
            ))
        }
        try? context.save()
    }

    @MainActor
    public static func delete(context: ModelContext, key: String) {
        var descriptor = FetchDescriptor<AnswerDraft>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }
}
