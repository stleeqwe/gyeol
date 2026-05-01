// 결 (Gyeol) — @main App entry

import SwiftUI
import GyeolCore
import GyeolUI

@main
public struct GyeolApp: App {
    @StateObject private var auth = AuthService()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .modelContainer(DraftSchema.container)
                .preferredColorScheme(nil)   // 시스템 follow
        }
    }
}

public struct RootView: View {
    @EnvironmentObject var auth: AuthService

    public var body: some View {
        Group {
            if !auth.isAuthenticated {
                NavigationStack {
                    OnboardingScreen()
                        .navigationDestination(for: OnboardingRoute.self) { route in
                            switch route {
                            case .signIn: SignInScreen()
                            }
                        }
                }
            } else if !auth.hasActiveConsent {
                NavigationStack { ConsentScreen() }
            } else {
                MainTabView()
            }
        }
        .background(Color.gyBg.ignoresSafeArea())
    }
}

public struct MainTabView: View {
    @State private var selection: Tab = .interview

    public enum Tab: Hashable { case interview, matches, chats, me }

    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack { InterviewHomeScreen() }
                .tabItem { Label("질문", systemImage: "questionmark.bubble") }
                .tag(Tab.interview)
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
    }
}
