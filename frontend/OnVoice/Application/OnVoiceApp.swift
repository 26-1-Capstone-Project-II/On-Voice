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
                .task(priority: .utility) {
                    // 분석 화면 진입 시 Whisper 첫 호출이 느리지 않도록
                    // 부팅 시점에 미리 mlmodelc 로드 + ANE 그래프를 워밍업한다.
                    await WhisperPhoneticTranscriptionService.shared.prewarm()
                }
        }
    }
}
