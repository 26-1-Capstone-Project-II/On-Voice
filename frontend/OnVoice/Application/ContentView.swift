//
//  ContentView.swift
//  OnVoice
//
import SwiftUI

enum OnVoiceTab {
    case home
    case library
}

struct ContentView: View {
    @State private var selectedTab: OnVoiceTab = .home

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeView(selectedTab: $selectedTab)
            case .library:
                LibraryView(selectedTab: $selectedTab)
            }
        }
        .background(Color.bg)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioRecorder())
}
