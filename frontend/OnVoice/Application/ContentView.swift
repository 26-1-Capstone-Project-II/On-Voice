//
//  ContentView.swift
//  OnVoice
//
import SwiftUI

enum OnVoiceTab: Equatable {
    case home
    case library
}

struct ContentView: View {
    @State private var selectedTab: OnVoiceTab = .home
    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)
                case .library:
                    LibraryView(selectedTab: $selectedTab)
                }
            } else {
                LoginView {
                    isLoggedIn = true
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
