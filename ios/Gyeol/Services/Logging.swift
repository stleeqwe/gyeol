// 결 (Gyeol) — OSLog 카테고리별 logger
//
// 정책 (PIPA 23조 정합):
// - 절대 금지: 사용자 raw 답변, summary 텍스트, raw_user_text, polished narrative, evidence quote
// - 허용: 카운트, duration_ms, status, ID(uuid 단축), enum(stance/qualitative/alignment_level), bool flag
// - OSLog %{public}@ vs %{private}@ — 기본 private, 명시적 public만 외부에 보임
//
// 사용 예:
//   GyLog.auth.info("apple_sign_in.start")
//   GyLog.speech.error("session_failed", error: err)
//   GyLog.match.debug("realtime.row_received", fields: ["match_id": id.short])

import Foundation
import OSLog

public enum GyLog {
    public static let auth = GyLogger(category: "auth")
    public static let interview = GyLogger(category: "interview")
    public static let speech = GyLogger(category: "speech")
    public static let match = GyLogger(category: "match")
    public static let chat = GyLogger(category: "chat")
    public static let realtime = GyLogger(category: "realtime")
    public static let api = GyLogger(category: "api")
}

public struct GyLogger {
    private let logger: Logger

    public init(category: String) {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gyeol.app", category: category)
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

    /// boundary trace stopwatch — duration_ms 자동 측정
    public func trace<T>(
        _ event: String,
        fields: [String: String] = [:],
        op: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        info("\(event).start", fields: fields)
        do {
            let result = try await op()
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            info("\(event).ok", fields: fields.merging(["duration_ms": String(duration)]) { _, new in new })
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

    private func format(_ event: String, _ fields: [String: String]) -> String {
        if fields.isEmpty { return event }
        let parts = fields.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(event) \(parts)"
    }
}

public extension UUID {
    /// 로그 노출용 단축 ID (앞 8자) — full UUID 대신 사용
    var short: String { uuidString.prefix(8).description }
}
