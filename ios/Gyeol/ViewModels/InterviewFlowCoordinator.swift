// 결 (Gyeol) — Interview Flow Coordinator
// Owns the typed navigation path for the pre-publish sequential interview shell.
// Replaces the prior hub-based navigation in `InterviewHomeScreen`.

import Foundation
import GyeolDomain
import SwiftUI

public enum InterviewFlowStep: Hashable {
    case domainIntro(DomainID)
    case domainAnswer(DomainID, isOpenQuestion: Bool)
    case domainFollowUpLoading(DomainID)
    case domainEnd(DomainID)
    case dealbreakers
    case selfReview

    public var shortLabel: String {
        switch self {
        case .domainIntro(let d): return "intro:\(d.rawValue)"
        case .domainAnswer(let d, let isOpen): return "answer:\(d.rawValue):\(isOpen ? "open" : "follow")"
        case .domainFollowUpLoading(let d): return "loading:\(d.rawValue)"
        case .domainEnd(let d): return "end:\(d.rawValue)"
        case .dealbreakers: return "dealbreakers"
        case .selfReview: return "self_review"
        }
    }
}

@MainActor
public final class InterviewFlowCoordinator: ObservableObject {
    @Published public var path: [InterviewFlowStep] = []
    @Published public var isPaused: Bool = false
    public let initialCursor: ResumeCursor

    private let auth: AuthService
    private var sessions: [DomainID: InterviewViewModel] = [:]

    public init(initialCursor: ResumeCursor, auth: AuthService) {
        self.initialCursor = initialCursor
        self.auth = auth
        GyLog.interview.info("flow.coordinator.init", fields: [
            "cursor": initialCursor.shortLabel,
        ])
    }

    /// Returns a stable per-domain VM. Coord retains it so all screens within a domain
    /// session (intro → answer → loading → answer → end) share the same answers/draft state.
    public func vm(for domain: DomainID) -> InterviewViewModel {
        if let existing = sessions[domain] { return existing }
        let vm = InterviewViewModel(domain: domain)
        sessions[domain] = vm
        Task { await vm.bootstrap() }
        return vm
    }

    /// Drops the cached VM for a domain — used after finalize so a re-entry recomputes state.
    public func resetSession(for domain: DomainID) {
        sessions.removeValue(forKey: domain)
    }

    // ─── Path transitions ──────────────────────────────────

    /// Resume landing CTA → push the cursor's initial step.
    /// For `.fresh`, the shell auto-pushes domain 1 intro on appear (skip landing).
    public func start() {
        switch initialCursor {
        case .fresh:
            path = [.domainIntro(.belief)]
        case .domainIntro(let d), .domainInProgress(let d):
            path = [.domainIntro(d)]
        case .dealbreakers:
            path = [.dealbreakers]
        }
        GyLog.interview.info("flow.start", fields: ["cursor": initialCursor.shortLabel])
    }

    public func advanceFromIntroToAnswer(domain: DomainID) {
        push(.domainAnswer(domain, isOpenQuestion: true))
    }

    public func advanceFromAnswerToLoading(domain: DomainID) {
        push(.domainFollowUpLoading(domain))
    }

    public func advanceFromLoadingToFollowUpAnswer(domain: DomainID) {
        push(.domainAnswer(domain, isOpenQuestion: false))
    }

    public func advanceFromLoadingToEnd(domain: DomainID) {
        push(.domainEnd(domain))
    }

    /// "다음 영역으로" — collapses the current domain stack frames and pushes the next
    /// domain's intro. If this is the last domain, pushes dealbreakers instead.
    public func advanceFromDomainEnd(domain: DomainID) {
        resetSession(for: domain)
        let idx = domain.indexNumber
        if let next = DomainID.allCases.first(where: { $0.indexNumber == idx + 1 }) {
            path = [.domainIntro(next)]
        } else {
            path = [.dealbreakers]
        }
        GyLog.interview.info("flow.domain_end.advance", fields: [
            "from_domain": domain.rawValue,
            "next": path.first?.shortLabel ?? "?",
        ])
    }

    /// "다음으로" on dealbreakers → self-review.
    public func advanceFromDealbreakers() {
        path = [.selfReview]
    }

    /// SelfReviewScreen calls this after a successful publish() — flips RootView to MainTabView.
    public func markPublished() {
        auth.markPublished()
    }

    /// "이 영역은 답변하지 않았습니다" / "비공개로 보관" — same as finalize-end-of-domain advance.
    /// Skip/private actions are committed by the VM itself; coord just navigates.
    public func advanceAfterAvoidanceAction(domain: DomainID) {
        advanceFromDomainEnd(domain: domain)
    }

    // ─── Pause / Resume ────────────────────────────────────

    public func pause() {
        guard !isPaused else { return }
        isPaused = true
        GyLog.interview.info("flow.pause", fields: ["depth": String(path.count)])
    }

    public func resume() {
        guard isPaused else { return }
        isPaused = false
        GyLog.interview.info("flow.resume", fields: ["depth": String(path.count)])
    }

    private func push(_ step: InterviewFlowStep) {
        path.append(step)
        GyLog.interview.info("flow.advance", fields: [
            "step": step.shortLabel,
            "depth": String(path.count),
        ])
    }
}
