//
//  ContentView.swift
//  OnVoice
//
import SwiftUI

enum OnVoiceTab: Equatable {
    case home
    case library
}

enum OnVoiceFlow: Equatable {
    case login
    case profileSetup
    case app
}

struct ContentView: View {
    @State private var selectedTab: OnVoiceTab = .home
    @State private var flow: OnVoiceFlow = .login
    @State private var userProfile = UserProfile.placeholder

    var body: some View {
        Group {
            switch flow {
            case .login:
                LoginView {
                    flow = .profileSetup
                }
            case .profileSetup:
                ProfileSetupView { profile in
                    userProfile = profile
                    flow = .app
                }
            case .app:
                switch selectedTab {
                case .home:
                    HomeView(
                        selectedTab: $selectedTab,
                        userProfile: $userProfile,
                        onLogout: handleLogout
                    )
                case .library:
                    LibraryView(
                        selectedTab: $selectedTab,
                        userProfile: $userProfile,
                        onLogout: handleLogout
                    )
                }
            }
        }
        .background(Color.bg)
    }

    private func handleLogout() {
        userProfile = .placeholder
        selectedTab = .home
        flow = .login
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioRecorder())
}
