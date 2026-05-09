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
                    HomeView(selectedTab: $selectedTab, userProfile: userProfile)
                case .library:
                    LibraryView(selectedTab: $selectedTab, userProfile: userProfile)
                }
            }
        }
        .background(Color.bg)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioRecorder())
}
