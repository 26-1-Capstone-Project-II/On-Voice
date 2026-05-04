//
//  NoiseMeter.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//


import SwiftUI
import AVFoundation
import ActivityKit

@Observable
class NoiseMeter{
    
    /// 싱글톤 인스턴스
    static let shared = NoiseMeter()
    
    let audioRecorder: AVAudioRecorder
    
    /// NoiseMeter - AVAudioRecorder를 위한 Timer
    var timer: Timer?
    
    /// NoiseMeter - LiveActivity update 주기(period) 부여를 위한 Timer
    var updateTimer: Timer?
    
    /// NoiseMeter - 현재 측정된 데시벨 크기
    var decibels: Float = 0
    
    /// NoiseMeter - 녹음 중인지 여부
    var isMeasuring: Bool {
        self.timer != nil
    }
    
    /// NoiseMeter - Live Activity의 Activity 객체
    var activity: Activity<OnVoiceLiveActivityAttributes>?
    
    /// NoiseMeter - LiveActivity의 LockScreen에서 사용자가 선택한 상황 title
    var nowSituation: Situation?
    
    var cancellation: Task<(), Never>?
    
    init() {
        let audioFileURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(
            "audio.m4a"
        )
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // AudioRecorder 객체 생성
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
        } catch let error {
            fatalError("Error creating audio recorder: \(error.localizedDescription)")
        }
    }
    
    /// 소리 측정 시작하는 함수
    func startMetering() async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            print("Error setting up audio session: \(error.localizedDescription)")
            return
        }
        
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()
        
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.audioRecorder.updateMeters()
                let db = self.audioRecorder.averagePower(forChannel: 0)
                self.decibels = self.convertToDecibels(db)
            }
        }
    }
    
    /// 소리 측정 종료하는 함수
    func stopMetering() {
        print(#function)
        audioRecorder.stop()
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.0)) {
                self.decibels = 0
            }
        }
    }
    
    /// 소리 측정 On/Off 함수
    func measure() async {
        if self.timer == nil {
            await self.startMetering()
        } else {
            self.stopMetering()
        }
    }
    
    /// Live Activity를 실행하는 함수
    func startLiveActivity() {
        print(#function)
        if self.activity == nil {
            let attributes = OnVoiceLiveActivityAttributes(name: "OnVoice")
            let contentState = self.liveActivityContentState()
            let content = ActivityContent(state: contentState, staleDate: nil, relevanceScore: 1)
            
            do {
                self.activity = try Activity<OnVoiceLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                print("LiveActivityManager: Error in LiveActivityManager: \(error.localizedDescription)")
            }
        }
        
        updateTimer?.invalidate()
        
        // TODO: - update 주기를 정확도와 연관지어 조절 기능 구현 및 timeInterval 픽스 필요.
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if self.cancellation != nil {
                self.cancellation?.cancel()
                self.cancellation = nil
            }
            self.cancellation = Task {
                await self.updateLiveActivity()
            }
        }
    }
    
    /// Live Activity를 종료하는 함수
    func endLiveActivity() {
        print(#function)
        Task {
            if let currentActivity = activity {
                await currentActivity.end(nil, dismissalPolicy: .immediate)
                print("Ending the Live Activity: \(currentActivity.id)")
                self.activity = nil
            }
        }
        cancellation?.cancel()
        updateTimer?.invalidate()
        updateTimer = nil
        self.stopMetering()
    }
    
    /// Live Activity를 업데이트하는 함수
    func updateLiveActivity() async {
        print(#function)
        let contentState = self.liveActivityContentState()
        await self.activity?.update(ActivityContent<OnVoiceLiveActivityAttributes.ContentState>(
            state: contentState,
            staleDate: nil
        ))
    }
    
    // TODO: - 보정 알고리즘 개선 필요
    /// dB 보정하는 함수
    private func convertToDecibels(_ dbFS: Float) -> Float {
        let referenceLevel: Float = 94.0
        let dbSPL = dbFS + referenceLevel
        return max(min(max(dbSPL, 0.0), 120.0) - 10, 0)
    }

    private func liveActivityContentState() -> OnVoiceLiveActivityAttributes.ContentState {
        let contentState = OnVoiceLiveActivityState.makeContentState(
            decibels: self.decibels,
            isMeasuring: self.isMeasuring,
            title: self.nowSituation?.title,
            thresholds: self.liveActivityThresholds()
        )
        print(contentState.progress)
        return contentState
    }

    private func liveActivityThresholds() -> OnVoiceLiveActivityState.Thresholds? {
        guard let decibels = self.nowSituation?.decibels else {
            return nil
        }

        return OnVoiceLiveActivityState.Thresholds(
            low: decibels.0,
            high: decibels.1
        )
    }
}
