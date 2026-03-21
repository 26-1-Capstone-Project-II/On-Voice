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
            .background(Color.suBlack)
            .tint(Color.point)
            .onAppear {
                UITabBar.appearance().unselectedItemTintColor = .suGray4
                UITabBar.appearance().barTintColor = .suGray9
                UITabBar.appearance().backgroundColor = .suGray9
            }
        }.background(Color.suBlack)
    }
}


#Preview {
    ContentView()
}
