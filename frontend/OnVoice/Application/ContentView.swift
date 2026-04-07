//
//  ContentView.swift
//  OnVoice
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var recorder: AudioRecorder
    
    var body: some View {
        ZStack {
            TabView{
                Tab("홈", systemImage: "house.fill") {HomeView()}
                Tab("모아보기", systemImage: "square.grid.2x2") {}
                Tab("설정", systemImage: "person") {}
            }
            .background(Color.bg)
            .tint(Color.main)
            .onAppear {
                UITabBar.appearance().unselectedItemTintColor = .gray4
                UITabBar.appearance().barTintColor = .gray9
                UITabBar.appearance().backgroundColor = .gray9
            }
        }.background(Color.bg)
    }
}


#Preview {
    ContentView()
}
