// 결 (Gyeol) — @main App entry

import SwiftUI
import GyeolCore
import GyeolDomain
import GyeolUI

/// 앱 시작 시각 (process start 근사) — cold start latency 측정용.
private let gyAppStartedAt = CFAbsoluteTimeGetCurrent()

@main
public struct GyeolApp: App {
    @StateObject private var auth = AuthService()
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        FontRegistration.registerOnce()
        let bootMs = Int((CFAbsoluteTimeGetCurrent() - gyAppStartedAt) * 1000)
        GyLog.app.info("launch.init", fields: [
            "bundle_id": Bundle.main.bundleIdentifier ?? "?",
            "boot_ms": String(bootMs),
        ])
        GyLog.app.signpostEvent("launch.init")
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .modelContainer(DraftSchema.container)
                .preferredColorScheme(nil)   // 시스템 follow
        }
        .onChange(of: scenePhase) { _, new in
            GyLog.app.info("scene.phase_change", fields: ["phase": String(describing: new)])
        }
    }
}

public struct RootView: View {
    @EnvironmentObject var auth: AuthService

    public var body: some View {
        Group { gateContent }
            .background(Color.gyBg.ignoresSafeArea())
            .modifier(RootRouteLogger(auth: auth))
    }

    @ViewBuilder
    private var gateContent: some View {
        if !auth.bootstrapResolved {
            SplashLoadingView()
        } else if !auth.isAuthenticated {
            unauthenticatedView
        } else if !auth.hasActiveConsent {
            NavigationStack { ConsentScreen() }
        } else {
            postConsentView
        }
    }

    @ViewBuilder
    private var unauthenticatedView: some View {
        NavigationStack {
            OnboardingScreen()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .signIn: SignInScreen()
                    }
                }
        }
    }

    @ViewBuilder
    private var postConsentView: some View {
        switch auth.publishState {
        case .published:
            MainTabView()
        case .unpublished(let cursor):
            InterviewShellView(initialCursor: cursor, auth: auth)
        case .none:
            SplashLoadingView()
        }
    }
}

/// Single-key route signature for observing all auth gate transitions in one .onChange call.
/// Avoids stacking multiple .onChange modifiers, which deeply nest generic types and exceed
/// the type-checker's complexity budget.
private struct RouteSignature: Equatable {
    let bootstrapResolved: Bool
    let isAuthenticated: Bool
    let hasActiveConsent: Bool
    let publishState: String

    var description: String {
        "boot=\(bootstrapResolved) auth=\(isAuthenticated) consent=\(hasActiveConsent) publish=\(publishState)"
    }
}

@MainActor
private func makeRouteSignature(_ auth: AuthService) -> RouteSignature {
    RouteSignature(
        bootstrapResolved: auth.bootstrapResolved,
        isAuthenticated: auth.isAuthenticated,
        hasActiveConsent: auth.hasActiveConsent,
        publishState: auth.publishState?.shortLabel ?? "nil"
    )
}

private struct RootRouteLogger: ViewModifier {
    @ObservedObject var auth: AuthService

    func body(content: Content) -> some View {
        content
            .onAppear { logReady() }
            .onChange(of: makeRouteSignature(auth)) { _, new in
                GyLog.app.info("root.route.changed", fields: ["sig": new.description])
            }
    }

    @MainActor
    private func logReady() {
        let firstReadyMs = Int((CFAbsoluteTimeGetCurrent() - gyAppStartedAt) * 1000)
        var fields: [String: String] = [:]
        fields["sig"] = makeRouteSignature(auth).description
        fields["first_ready_ms"] = String(firstReadyMs)
        GyLog.app.info("root.ready", fields: fields)
    }
}

private struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            Color.gyBg.ignoresSafeArea()
            ProgressView()
                .tint(Color.gyText)
                .scaleEffect(1.2)
        }
    }
}

public struct MainTabView: View {
    @State private var selection: Tab = .matches

    public enum Tab: Hashable, CustomStringConvertible {
        case matches, chats, me
        public var description: String {
            switch self {
            case .matches: return "matches"
            case .chats: return "chats"
            case .me: return "me"
            }
        }
    }

    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack { MatchListScreen() }
                .tabItem { Label("매칭", systemImage: "person.2") }
                .tag(Tab.matches)
            NavigationStack { ChatRoomsScreen() }
                .tabItem { Label("대화", systemImage: "bubble.left.and.bubble.right") }
                .tag(Tab.chats)
            NavigationStack { MeScreen() }
                .tabItem { Label("나", systemImage: "person.crop.circle") }
                .tag(Tab.me)
        }
        .tint(Color.gyText)
        .onAppear { GyLog.ui.info("tab.appear", fields: ["tab": selection.description]) }
        .onChange(of: selection) { old, new in
            GyLog.ui.info("tab.switch", fields: [
                "from": old.description,
                "to": new.description,
            ])
        }
    }
}
