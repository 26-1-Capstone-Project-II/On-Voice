//
//  OnVoiceApp.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI
import SwiftData

@main
struct OnVoiceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recorder = AudioRecorder.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recorder)
        }
    }
}
