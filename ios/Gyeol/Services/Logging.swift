// 결 (Gyeol) — OSLog 카테고리별 logger + OSSignpost 성능 instrumentation
//
// 정책 (PIPA 23조 정합):
// - 절대 금지: 사용자 raw 답변, summary 텍스트, raw_user_text, polished narrative, evidence quote
// - 허용: 카운트, duration_ms, status, ID(uuid 단축), enum(stance/qualitative/alignment_level), bool flag
// - OSLog %{public}@ vs %{private}@ — 기본 private, 명시적 public만 외부에 보임
//
// 카테고리 (9):
//   app       — 앱 lifecycle (launch, scene phase, GyeolClient init, cold-start path)
//   ui        — View appear/disappear, navigation, modal, tab 전환 (성능 측정 단서)
//   auth      — Apple Sign In, consent, account
//   interview — InterviewService + InterviewViewModel
//   speech    — Apple Speech on-device session
//   match     — Match list + detail + interest
//   chat      — chat rooms + messages
//   realtime  — Supabase Realtime channel subscribe/unsubscribe/event
//   api       — generic Edge Function fallback
//   draft     — local SwiftData drafts (offline-first)
//
// 사용 예:
//   GyLog.auth.info("apple_sign_in.start")
//   GyLog.speech.error("session_failed", error: err)
//   GyLog.match.debug("realtime.row_received", fields: ["match_id": id.short])
//   await GyLog.interview.trace("submit_answer", fields: [...]) { try await api(...) }
//   GyLog.app.measure("root_view.route") { decideRoute() }
//   GyLog.match.signpost("match_detail.render", id: matchId.short) { ... }

import Foundation
import OSLog
import SwiftUI

public enum GyLog {
    public static let app = GyLogger(category: "app")
    public static let ui = GyLogger(category: "ui")
    public static let auth = GyLogger(category: "auth")
    public static let interview = GyLogger(category: "interview")
    public static let speech = GyLogger(category: "speech")
    public static let match = GyLogger(category: "match")
    public static let chat = GyLogger(category: "chat")
    public static let realtime = GyLogger(category: "realtime")
    public static let api = GyLogger(category: "api")
    public static let draft = GyLogger(category: "draft")
    /// ADR-017 raw LLM/answer trace. Output only when both `#if DEBUG` and the
    /// `GYEOL_TRACE_RAW` Swift compilation flag are set. Release builds and
    /// non-flagged Debug builds compile away the body, so PII never leaks.
    public static let trace = GyLogger(category: "trace")
}

public struct GyLogger {
    private let logger: Logger
    private let signposter: OSSignposter
    private let category: String

    public init(category: String) {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.gyeol.app"
        self.logger = Logger(subsystem: subsystem, category: category)
        self.signposter = OSSignposter(subsystem: subsystem, category: category)
        self.category = category
    }

    public func debug(_ event: String, fields: [String: String] = [:]) {
        logger.debug("\(self.format(event, fields), privacy: .public)")
    }

    public func info(_ event: String, fields: [String: String] = [:]) {
        logger.info("\(self.format(event, fields), privacy: .public)")
    }

    public func warn(_ event: String, fields: [String: String] = [:]) {
        logger.warning("\(self.format(event, fields), privacy: .public)")
    }

    public func error(_ event: String, error: Error? = nil, fields: [String: String] = [:]) {
        var combined = fields
        if let error {
            combined["error_message"] = error.localizedDescription
            combined["error_class"] = String(describing: type(of: error))
        }
        logger.error("\(self.format(event, combined), privacy: .public)")
    }

    /// ADR-017 raw text trace. Outputs the actual text payload (user answer,
    /// follow-up question, analysis content) for quality monitoring.
    /// **Compiled out** unless both `#if DEBUG` and `GYEOL_TRACE_RAW` are set
    /// (configure via Xcode build settings → OTHER_SWIFT_FLAGS).
    /// Release builds and non-flagged Debug builds emit no log line and pay
    /// no allocation cost. See `CLAUDE.md` "Logging Policy" for the policy boundary.
    public func traceText(_ event: String, text: String, fields: [String: String] = [:]) {
        #if DEBUG && GYEOL_TRACE_RAW
        var combined = fields
        combined["text"] = text
        logger.info("\(self.format(event, combined), privacy: .public)")
        #endif
    }

    /// async boundary trace — `event.start` / `event.ok` / `event.fail` + duration_ms 자동 측정 + OSSignpost interval.
    public func trace<T>(
        _ event: String,
        fields: [String: String] = [:],
        op: () async throws -> T
    ) async rethrows -> T {
        let state = signposter.beginInterval(staticName(event), id: signposter.makeSignpostID())
        let start = CFAbsoluteTimeGetCurrent()
        info("\(event).start", fields: fields)
        do {
            let result = try await op()
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            signposter.endInterval(staticName(event), state)
            info("\(event).ok", fields: fields.merging(["duration_ms": String(duration)]) { _, new in new })
            return result
        } catch {
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            signposter.endInterval(staticName(event), state)
            self.error(
                "\(event).fail",
                error: error,
                fields: fields.merging(["duration_ms": String(duration)]) { _, new in new }
            )
            throw error
        }
    }

    /// 동기 measure — async 아닌 코드 블록의 duration_ms 측정 (예: View body branch, draft I/O).
    @discardableResult
    public func measure<T>(
        _ event: String,
        fields: [String: String] = [:],
        op: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let result = try op()
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            // 0ms 미만은 노이즈 — debug 레벨로
            if duration >= 1 {
                info("\(event).done", fields: fields.merging(["duration_ms": String(duration)]) { _, new in new })
            } else {
                debug("\(event).done", fields: fields.merging(["duration_ms": String(duration)]) { _, new in new })
            }
            return result
        } catch {
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            self.error(
                "\(event).fail",
                error: error,
                fields: fields.merging(["duration_ms": String(duration)]) { _, new in new }
            )
            throw error
        }
    }

    /// OSSignpost interval — Instruments timeline 상관용. begin/end 짝 사용.
    public func signpostBegin(_ event: String) -> OSSignpostIntervalState {
        signposter.beginInterval(staticName(event), id: signposter.makeSignpostID())
    }

    public func signpostEnd(_ event: String, _ state: OSSignpostIntervalState) {
        signposter.endInterval(staticName(event), state)
    }

    /// 단발 signpost event (instant). Instruments에서 timeline marker로 표시.
    public func signpostEvent(_ event: String) {
        signposter.emitEvent(staticName(event))
    }

    private func format(_ event: String, _ fields: [String: String]) -> String {
        if fields.isEmpty { return event }
        let parts = fields.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(event) \(parts)"
    }

    private func staticName(_ event: String) -> StaticString {
        // OSSignposter requires StaticString — 동적 event 이름은 카테고리만 표시.
        switch category {
        case "app": return "app.interval"
        case "ui": return "ui.interval"
        case "auth": return "auth.interval"
        case "interview": return "interview.interval"
        case "speech": return "speech.interval"
        case "match": return "match.interval"
        case "chat": return "chat.interval"
        case "realtime": return "realtime.interval"
        case "api": return "api.interval"
        case "draft": return "draft.interval"
        default: return "gyeol.interval"
        }
    }
}

public extension UUID {
    /// 로그 노출용 단축 ID (앞 8자) — full UUID 대신 사용
    var short: String { uuidString.prefix(8).description }
}

/// 화면 lifecycle 로깅 helper — `.task`/`.onAppear`/`.onDisappear`에 부착.
/// 사용:
///   .gyTrackAppear("MatchListScreen")
///
/// 내부적으로 GyLog.ui category 사용. 화면 이름만 노출 (PII 없음).
public extension View {
    func gyTrackAppear(_ screenName: String, fields: [String: String] = [:]) -> some View {
        self
            .onAppear { GyLog.ui.info("screen.appear", fields: fields.merging(["screen": screenName]) { _, new in new }) }
            .onDisappear { GyLog.ui.info("screen.disappear", fields: fields.merging(["screen": screenName]) { _, new in new }) }
    }
}
