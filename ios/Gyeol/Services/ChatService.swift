// 결 (Gyeol) — 대화방 + 메시지 Realtime
// Architecture §5.2 C5

import Foundation
import GyeolDomain
import Supabase

@MainActor
public final class ChatService: ObservableObject {
    @Published public private(set) var rooms: [ChatRoom] = []
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public var lastError: String?

    private var roomsChannel: RealtimeChannelV2?
    private var messagesChannel: RealtimeChannelV2?
    private var client: SupabaseClient { GyeolClient.shared.supabase }

    public init() {}

    public func loadRooms() async {
        guard let userId = GyeolClient.shared.currentUserId else {
            GyLog.chat.warn("rooms.load.no_user")
            return
        }
        do {
            let rows: [ChatRoom] = try await GyLog.chat.trace("rooms.load", fields: ["user_id": userId.short]) {
                try await client.from("chat_rooms")
                    .select()
                    .or("user_a_id.eq.\(userId.uuidString),user_b_id.eq.\(userId.uuidString)")
                    .order("last_message_at", ascending: false, nullsFirst: false)
                    .execute()
                    .value
            }
            self.rooms = rows
            GyLog.chat.info("rooms.load.result", fields: ["count": String(rows.count)])
        } catch {
            self.lastError = error.localizedDescription
            GyLog.chat.error("rooms.load.fail", error: error)
        }
    }

    public func subscribeRooms() async {
        guard let userId = GyeolClient.shared.currentUserId else { return }
        GyLog.realtime.info("chat_rooms.subscribe.start", fields: ["user_id": userId.short])
        let ch = client.realtimeV2.channel("chat_rooms:\(userId.uuidString)")
        let changes = ch.postgresChange(AnyAction.self, schema: "public", table: "chat_rooms")
        do {
            try await ch.subscribeWithError()
        } catch {
            self.lastError = error.localizedDescription
            GyLog.realtime.error("chat_rooms.subscribe_failed", error: error, fields: ["user_id": userId.short])
            return
        }
        self.roomsChannel = ch
        GyLog.realtime.info("chat_rooms.subscribe.ok", fields: ["user_id": userId.short])
        Task {
            for await _ in changes {
                GyLog.realtime.debug("chat_rooms.change_received")
                await self.loadRooms()
            }
            GyLog.realtime.info("chat_rooms.change_stream_ended")
        }
    }

    public func openRoom(_ roomId: UUID) async {
        await unsubscribeMessages()
        GyLog.chat.info("room.open", fields: ["room_id": roomId.short])
        do {
            let rows: [ChatMessage] = try await client.from("chat_messages")
                .select()
                .eq("room_id", value: roomId.uuidString)
                .order("created_at", ascending: true)
                .limit(200)
                .execute()
                .value
            self.messages = rows
            GyLog.chat.info("room.messages_loaded", fields: ["room_id": roomId.short, "count": String(rows.count)])
        } catch {
            self.lastError = error.localizedDescription
            GyLog.chat.error("room.messages_load_failed", error: error, fields: ["room_id": roomId.short])
        }
        let ch = client.realtimeV2.channel("chat:\(roomId.uuidString)")
        let changes = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_messages",
            filter: .eq("room_id", value: roomId)
        )
        do {
            try await ch.subscribeWithError()
        } catch {
            self.lastError = error.localizedDescription
            GyLog.realtime.error("chat.subscribe_failed", error: error, fields: ["room_id": roomId.short])
            return
        }
        self.messagesChannel = ch
        GyLog.realtime.info("chat.subscribe.ok", fields: ["room_id": roomId.short])
        Task {
            for await change in changes {
                if let row = try? change.decodeRecord(as: ChatMessage.self, decoder: defaultDecoder()) {
                    self.messages.append(row)
                    GyLog.realtime.debug("chat.message_received", fields: [
                        "room_id": roomId.short,
                        "is_system": String(row.isSystem),
                    ])
                }
            }
        }
    }

    public func unsubscribeMessages() async {
        if let ch = messagesChannel {
            await ch.unsubscribe()
            self.messagesChannel = nil
            GyLog.realtime.info("chat.unsubscribe")
        }
        self.messages = []
    }

    public func unsubscribeRooms() async {
        if let ch = roomsChannel {
            await ch.unsubscribe()
            self.roomsChannel = nil
            GyLog.realtime.info("chat_rooms.unsubscribe")
        }
    }

    public func send(roomId: UUID, body: String) async throws {
        guard let userId = GyeolClient.shared.currentUserId else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else {
            GyLog.chat.warn("send.invalid_length", fields: ["chars": String(trimmed.count)])
            return
        }
        try await GyLog.chat.trace("send_message", fields: [
            "room_id": roomId.short,
            "sender_id": userId.short,
            "chars": String(trimmed.count),
        ]) {
            struct Insert: Encodable {
                let room_id: UUID
                let sender_id: UUID
                let is_system: Bool
                let body: String
            }
            try await client.from("chat_messages")
                .insert(Insert(room_id: roomId, sender_id: userId, is_system: false, body: trimmed))
                .execute()
        }
    }
}

private func defaultDecoder() -> JSONDecoder {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return dec
}
