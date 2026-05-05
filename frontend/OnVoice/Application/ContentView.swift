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

    var body: some View {
        Group {
            switch flow {
            case .login:
                LoginView {
                    flow = .profileSetup
                }
            case .profileSetup:
                ProfileSetupView {
                    flow = .app
                }
            case .app:
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)
                case .library:
                    LibraryView(selectedTab: $selectedTab)
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
