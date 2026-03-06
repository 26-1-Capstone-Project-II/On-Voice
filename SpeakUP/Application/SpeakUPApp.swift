//
//  SpeakUPApp.swift
//  SpeakUP
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI
import SwiftData

@main

struct SpeakUPApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var recorder = AudioRecorder()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recorder)
        }
    }
}
