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
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let c = try ModelContainer(for: AnswerDraft.self)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            GyLog.draft.info("container.init", fields: ["duration_ms": String(ms)])
            return c
        } catch {
            GyLog.draft.error("container.init_failed", error: error)
            fatalError("Draft container failed: \(error)")
        }
    }()
}

public enum DraftStore {
    public static func makeKey(domain: DomainID, isOpenQuestion: Bool, followUpQuestion: String?) -> String {
        let questionPart = isOpenQuestion ? "open" : (followUpQuestion ?? "follow-up")
        return "\(domain.rawValue)|\(questionPart)"
    }

    /// 로그 노출용 안전 식별자 — domain rawValue + open/follow 분류만 노출. 질문 본문 미포함.
    private static func keyTag(_ key: String) -> String {
        let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return "unknown" }
        let kind = parts[1] == "open" ? "open" : "follow"
        return "\(parts[0])|\(kind)"
    }

    @MainActor
    public static func load(context: ModelContext, key: String) -> String? {
        let start = CFAbsoluteTimeGetCurrent()
        var descriptor = FetchDescriptor<AnswerDraft>(
            predicate: #Predicate { $0.key == key },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let row = try? context.fetch(descriptor).first
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        GyLog.draft.debug("load", fields: [
            "key_tag": keyTag(key),
            "found": String(row != nil),
            "duration_ms": String(ms),
            "chars": String(row?.text.count ?? 0),
        ])
        return row?.text
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
        let start = CFAbsoluteTimeGetCurrent()
        var descriptor = FetchDescriptor<AnswerDraft>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        let existing = try? context.fetch(descriptor).first
        if let existing {
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
        do {
            try context.save()
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            GyLog.draft.debug("upsert", fields: [
                "key_tag": keyTag(key),
                "kind": existing != nil ? "update" : "insert",
                "chars": String(text.count),
                "duration_ms": String(ms),
            ])
        } catch {
            GyLog.draft.error("upsert.save_failed", error: error, fields: [
                "key_tag": keyTag(key),
            ])
        }
    }

    @MainActor
    public static func delete(context: ModelContext, key: String) {
        let start = CFAbsoluteTimeGetCurrent()
        var descriptor = FetchDescriptor<AnswerDraft>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            do {
                try context.save()
                let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                GyLog.draft.info("delete", fields: [
                    "key_tag": keyTag(key),
                    "duration_ms": String(ms),
                ])
            } catch {
                GyLog.draft.error("delete.save_failed", error: error, fields: ["key_tag": keyTag(key)])
            }
        } else {
            GyLog.draft.debug("delete.not_found", fields: ["key_tag": keyTag(key)])
        }
    }
}
