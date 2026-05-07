// 결 (Gyeol) — Supabase 클라이언트 래퍼

import Foundation
import Supabase

public enum GyeolEnv {
    public static let supabaseURL: URL = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: s) else {
            fatalError("SUPABASE_URL missing in Info.plist")
        }
        return url
    }()

    public static let supabaseAnonKey: String = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !s.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist")
        }
        return s
    }()
}

@MainActor
public final class GyeolClient {
    public static let shared = GyeolClient()

    public let supabase: SupabaseClient

    private init() {
        let start = CFAbsoluteTimeGetCurrent()
        self.supabase = SupabaseClient(
            supabaseURL: GyeolEnv.supabaseURL,
            supabaseKey: GyeolEnv.supabaseAnonKey
        )
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        GyLog.app.info("supabase_client.init", fields: [
            "duration_ms": String(ms),
            "host": GyeolEnv.supabaseURL.host ?? "?",
        ])
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Auth.Session {
        try await GyLog.auth.trace("supabase.id_token_sign_in") {
            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        }
    }

    public func signOut() async throws {
        try await GyLog.auth.trace("supabase.sign_out") {
            try await supabase.auth.signOut()
        }
    }

    public var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }
}
