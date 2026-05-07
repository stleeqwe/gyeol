// 결 (Gyeol) — Apple Sign In + 동의 + 세션
// 시스템설계 v3 §6 + 핵심질문체계 v7 §13

import AuthenticationServices
import CryptoKit
import Foundation
import GyeolDomain
import Supabase
#if os(iOS)
import UIKit
#endif

@MainActor
public final class AuthService: NSObject, ObservableObject {
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var userId: UUID?
    @Published public private(set) var hasActiveConsent: Bool = false
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var bootstrapResolved: Bool = false
    @Published public private(set) var publishState: PublishState?
    @Published public var lastError: String?

    private var currentNonce: String?

    public override init() {
        super.init()
        Task { await refresh() }
    }

    public func refresh() async {
        defer { self.bootstrapResolved = true }
        let id = GyeolClient.shared.currentUserId
        self.userId = id
        self.isAuthenticated = id != nil
        GyLog.auth.info("refresh.start", fields: [
            "has_session": String(id != nil),
            "user_id": id?.short ?? "?",
        ])
        guard id != nil else {
            self.hasActiveConsent = false
            self.publishState = nil
            GyLog.auth.info("refresh.no_session")
            return
        }
        do {
            let bootstrap = try await bootstrapUser()
            self.userId = bootstrap.userId
            self.hasActiveConsent = bootstrap.hasActiveConsent
            if bootstrap.profilePublishedAt != nil {
                UserDefaults.standard.set(true, forKey: Self.publishedKey(userId: bootstrap.userId))
            }
            GyLog.auth.info("refresh.ok", fields: [
                "user_id": bootstrap.userId.short,
                "has_active_consent": String(bootstrap.hasActiveConsent),
            ])
        } catch {
            self.hasActiveConsent = false
            self.lastError = error.localizedDescription
            GyLog.auth.error("bootstrap_user.fail", error: error)
        }
        if hasActiveConsent {
            await refreshPublishState()
        } else {
            publishState = nil
        }
    }

    /// Recomputes publish state. The backend owns matching-pool publish state;
    /// UserDefaults mirrors successful publish/bootstrap state for fast local resume.
    /// Call on launch and after publish success.
    public func refreshPublishState() async {
        guard isAuthenticated, hasActiveConsent, let userId else {
            self.publishState = nil
            return
        }
        if Self.isLocallyPublished(userId: userId) {
            self.publishState = .published
            GyLog.auth.info("publish_state.refresh.ok", fields: ["state": "published(local)"])
            return
        }
        do {
            let cursor = try await InterviewService.shared.computeResumeCursor()
            let state = PublishState.unpublished(cursor)
            self.publishState = state
            GyLog.auth.info("publish_state.refresh.ok", fields: ["state": state.shortLabel])
        } catch {
            GyLog.auth.error("publish_state.refresh.fail", error: error)
        }
    }

    /// Records publish success locally. Call after publish() Edge Function returns OK.
    /// Survives app restarts; cleared on signOut/softDeleteAccount.
    public func markPublished() {
        guard let userId else { return }
        UserDefaults.standard.set(true, forKey: Self.publishedKey(userId: userId))
        self.publishState = .published
        GyLog.auth.info("publish_state.mark_published", fields: ["user_id": userId.short])
    }

    private static func publishedKey(userId: UUID) -> String {
        "gyeol.published.\(userId.uuidString)"
    }

    private static func isLocallyPublished(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: publishedKey(userId: userId))
    }

    private func clearLocalPublishedFlag() {
        guard let userId else { return }
        UserDefaults.standard.removeObject(forKey: Self.publishedKey(userId: userId))
    }

    public func startAppleSignIn() {
        GyLog.auth.info("apple_sign_in.start")
        let nonce = randomNonce()
        currentNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    public func recordConsent(consentTextVersion: String,
                              ipAddress: String? = nil) async throws {
        guard let userId else { throw AuthError.notSignedIn }
        try await GyLog.auth.trace("consent.record", fields: [
            "consent_text_version": consentTextVersion,
            "user_id": userId.short,
        ]) {
            struct Body: Encodable {
                let consent_text_version: String
                let ip_address: String?
            }
            let body = Body(
                consent_text_version: consentTextVersion,
                ip_address: ipAddress
            )
            try await GyeolClient.shared.supabase.functions.invoke(
                "submit-consent",
                options: .init(body: body)
            )
        }
        self.hasActiveConsent = true
    }

    public func signOut() async {
        GyLog.auth.info("sign_out.start")
        do {
            clearLocalPublishedFlag()
            try await GyeolClient.shared.signOut()
            self.userId = nil
            self.isAuthenticated = false
            self.hasActiveConsent = false
            self.publishState = nil
            GyLog.auth.info("sign_out.ok")
        } catch {
            self.lastError = error.localizedDescription
            GyLog.auth.error("sign_out.fail", error: error)
        }
    }

    public func loadConsentHistory() async throws -> [ConsentRecord] {
        guard let userId else { throw AuthError.notSignedIn }
        return try await GyLog.auth.trace("consent.history.load", fields: ["user_id": userId.short]) {
            try await GyeolClient.shared.supabase.from("consents")
                .select("""
                    id,
                    consented_at,
                    revoked_at,
                    consent_text_version,
                    sensitive_data_processing,
                    voice_on_device_disclosed,
                    raw_quote_isolation_disclosed,
                    no_ai_training_disclosed,
                    data_residency_disclosed
                    """)
                .eq("user_id", value: userId.uuidString)
                .order("consented_at", ascending: false)
                .execute()
                .value
        }
    }

    public func softDeleteAccount() async throws {
        guard let userId else { throw AuthError.notSignedIn }
        let now = Date()
        let purgeAt = Calendar(identifier: .gregorian).date(byAdding: .day, value: 30, to: now) ?? now
        let encoder = ISO8601DateFormatter()
        struct Update: Encodable {
            let deleted_at: String
            let deletion_purges_at: String
            let last_active_at: String
        }
        _ = try await GyLog.auth.trace("account.soft_delete", fields: ["user_id": userId.short]) {
            try await GyeolClient.shared.supabase.from("users")
                .update(Update(
                    deleted_at: encoder.string(from: now),
                    deletion_purges_at: encoder.string(from: purgeAt),
                    last_active_at: encoder.string(from: now)
                ))
                .eq("id", value: userId.uuidString)
                .execute()
        }
        clearLocalPublishedFlag()
        try await GyeolClient.shared.signOut()
        self.userId = nil
        self.isAuthenticated = false
        self.hasActiveConsent = false
        self.publishState = nil
    }

    private func bootstrapUser() async throws -> BootstrapReply {
        struct Empty: Encodable {}
        return try await GyLog.auth.trace("bootstrap_user") {
            try await GyeolClient.shared.supabase.functions.invoke(
                "bootstrap-user",
                options: .init(body: Empty())
            )
        }
    }
}

private struct BootstrapReply: Decodable {
    let userId: UUID
    let hasActiveConsent: Bool
    let profilePublishedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case hasActiveConsent = "has_active_consent"
        case profilePublishedAt = "profile_published_at"
    }
}

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
#if os(iOS)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
#else
        ASPresentationAnchor()
#endif
    }

    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            self.lastError = "apple_credential_invalid"
            GyLog.auth.error("apple_credential.invalid")
            return
        }
        GyLog.auth.info("apple_credential.received", fields: ["token_chars": String(token.count)])
        Task { @MainActor in
            self.isProcessing = true
            defer { self.isProcessing = false }
            do {
                _ = try await GyLog.auth.trace("supabase_sign_in") {
                    try await GyeolClient.shared.signInWithApple(idToken: token, nonce: nonce)
                }
                await self.refresh()
                GyLog.auth.info("apple_sign_in.ok", fields: ["user_id": self.userId?.short ?? "?"])
            } catch {
                self.lastError = error.localizedDescription
                GyLog.auth.error("apple_sign_in.fail", error: error)
            }
        }
    }

    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithError error: Error) {
        self.lastError = error.localizedDescription
        GyLog.auth.error("apple_sign_in.delegate_error", error: error)
    }
}

public enum AuthError: Error, LocalizedError {
    case notSignedIn
    case appleCredentialInvalid
    public var errorDescription: String? {
        switch self {
        case .notSignedIn: return "로그인되지 않음"
        case .appleCredentialInvalid: return "Apple 자격 증명 누락"
        }
    }
}

private func randomNonce(length: Int = 32) -> String {
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if status != errSecSuccess { fatalError("nonce gen failed") }
        for byte in randoms where remaining > 0 {
            if byte < charset.count {
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}
