// 결 (Gyeol) — 매칭 후보 목록 + Realtime 구독
// 시스템설계 v3 §2.2 + Architecture §5.2 Reactive Sync C3·C4

import Foundation
import Combine
import GyeolDomain
import Supabase

@MainActor
public final class MatchService: ObservableObject {
    public static let shared = MatchService()

    @Published public private(set) var matches: [Match] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var lastError: String?

    private var realtimeChannel: RealtimeChannelV2?
    private var client: SupabaseClient { GyeolClient.shared.supabase }

    private init() {}

    public func loadInitial() async {
        guard let userId = GyeolClient.shared.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            await prepareRecommendations()
            let rows: [Match] = try await GyLog.match.trace("load_initial", fields: ["user_id": userId.short]) {
                try await client.from("matches")
                    .select()
                    .eq("viewer_id", value: userId.uuidString)
                    .eq("recommendation_status", value: "ready")
                    .order("final_score", ascending: false)
                    .limit(30)
                    .execute()
                    .value
            }
            self.matches = rows
            GyLog.match.info("load_initial.result", fields: ["count": String(rows.count)])
        } catch {
            self.lastError = error.localizedDescription
            GyLog.match.error("load_initial.error", error: error)
        }
    }

    public func subscribeRealtime() async {
        guard let userId = GyeolClient.shared.currentUserId else { return }
        GyLog.realtime.info("matches.subscribe.start", fields: ["user_id": userId.short])
        let channel = client.realtimeV2.channel("matches:\(userId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "matches",
            filter: .eq("viewer_id", value: userId)
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            self.lastError = error.localizedDescription
            GyLog.realtime.error("matches.subscribe.fail", error: error, fields: ["user_id": userId.short])
            return
        }
        self.realtimeChannel = channel
        GyLog.realtime.info("matches.subscribe.ok")
        Task {
            for await change in changes {
                GyLog.realtime.debug("matches.change_received")
                await self.handleChange(change)
            }
        }
    }

    public func unsubscribe() async {
        if let ch = realtimeChannel {
            await ch.unsubscribe()
            self.realtimeChannel = nil
            GyLog.realtime.info("matches.unsubscribe")
        }
    }

    private func handleChange(_ change: AnyAction) async {
        // 단순화: 변경 발생 시 전체 리로드 (페이지 30 작음)
        await loadInitial()
    }

    // ─── 후보 카드 펼침 — 결정론 사전 계산 트리거 ────────────

    public func ensureExplanation(matchId: UUID) async {
        struct Body: Encodable { let match_id: UUID }
        do {
            try await client.functions.invoke(
                "request-explanation",
                options: .init(body: Body(match_id: matchId))
            )
            await loadInitial()
        } catch {
            GyLog.match.warn("explanation.request_failed", fields: [
                "match_id": matchId.short,
                "error": error.localizedDescription,
            ])
        }
    }

    private func prepareRecommendations() async {
        struct Body: Encodable { let limit: Int }
        do {
            try await GyLog.match.trace("recommendations.prepare") {
                try await client.functions.invoke(
                    "request-explanation",
                    options: .init(body: Body(limit: 30))
                )
            }
        } catch {
            self.lastError = error.localizedDescription
            GyLog.match.warn("recommendations.prepare_failed", fields: ["error": error.localizedDescription])
        }
    }

    public func setInterest(matchId: UUID, interested: Bool) async throws {
        try await GyLog.match.trace("set_interest", fields: [
            "match_id": matchId.short,
            "interested": String(interested),
        ]) {
            struct Update: Encodable { let viewer_interest: MatchInterest }
            try await client.from("matches")
                .update(Update(viewer_interest: interested ? .interested : .declined))
                .eq("id", value: matchId.uuidString)
                .execute()
        }
    }
}
