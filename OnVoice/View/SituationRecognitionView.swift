//
//  SituationRecognitionView.swift
//  OnVoice
//
//  Created by 이윤지 on 9/15/25.
//

import SwiftUI
import AVFoundation

struct SituationRecognitionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var progress: Double = 0.0
    @State private var recognitionMessage = "주변 배경 소음을 인식하고 있어요!"
    @State private var isRecognizing = false
    @State private var detectedSituation: Situation?
    @State private var shouldNavigateToFeedback = false
    @State private var ambientNoiseLevel: Float = 0
    
    // 소음 측정을 위한 오디오 레코더
    @State private var audioRecorder: AVAudioRecorder?
    @State private var timer: Timer?
    @State private var samples: [Float] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.suBlack.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // 상태 메시지
                    Text(recognitionMessage)
                        .font(.Pretendard.Regular.size17)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // 프로그레스 바
                    ZStack(alignment: .leading) {
                        // 배경 (회색)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.suGray6)
                            .frame(width: 175, height: 8)
                        
                        // 진행도 (보라색)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.point)
                            .frame(width: 175 * progress, height: 8)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)  // 탭바 숨기기
            .navigationDestination(isPresented: $shouldNavigateToFeedback) {
                FeedbackView(currentSituation: .constant(detectedSituation))
            }
        }
        .onAppear {
            // View 진입 시 자동으로 측정 시작
            startRecognition()
        }
        .onDisappear {
            stopRecognition()
        }
    }
    
    // MARK: - 소음 인식 시작
    private func startRecognition() {
        isRecognizing = true
        progress = 0.0
        samples = []
        recognitionMessage = "주변 배경 소음을 인식하고 있어요!"
        
        setupAudioRecorder()
        
        // 진행도 업데이트 타이머
        var elapsedTime = 0.0
        let totalTime = 5.0 // 5초 동안 측정
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            progress = min(elapsedTime / totalTime, 1.0)
            
            // 50% 지점에서 메시지 변경
            if progress >= 0.5 && progress < 0.55 {
                withAnimation {
                    recognitionMessage = "조용한 상태를 유지하면 더욱 정확해져요"
                }
            }
            
            // 100% 완료
            if progress >= 1.0 {
                completeRecognition()
            }
        }
    }
    
    // MARK: - 오디오 레코더 설정
    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("temp_noise_measurement.m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            // 소음 레벨 측정 타이머
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                guard let recorder = audioRecorder, recorder.isRecording else {
                    timer.invalidate()
                    return
                }
                
                recorder.updateMeters()
                let decibels = recorder.averagePower(forChannel: 0)
                let normalizedDecibels = convertToDecibels(decibels)
                samples.append(normalizedDecibels)
                
                if !isRecognizing {
                    timer.invalidate()
                }
            }
        } catch {
            print("오디오 레코더 설정 실패: \(error)")
        }
    }
    
    // MARK: - dB 변환
    private func convertToDecibels(_ dbFS: Float) -> Float {
        let referenceLevel: Float = 94.0
        let dbSPL = dbFS + referenceLevel
        return max(min(max(dbSPL, 0.0), 120.0) - 10, 0)
    }
    
    // MARK: - 인식 완료
    private func completeRecognition() {
        stopRecognition()
        
        // 평균 소음 레벨 계산
        let averageNoise = samples.isEmpty ? 0 : samples.reduce(0, +) / Float(samples.count)
        
        // 상황 판단 (50dB 기준)
        // quietTalking: 평균 소음이 50dB 미만
        // loudTalking: 평균 소음이 50dB 이상
        detectedSituation = averageNoise < 50 ? .quietTalking : .loudTalking
        
        // 바로 FeedbackView로 이동
        shouldNavigateToFeedback = true
    }
    
    // MARK: - 인식 중지
    private func stopRecognition() {
        isRecognizing = false
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        
        // 오디오 세션 비활성화
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
