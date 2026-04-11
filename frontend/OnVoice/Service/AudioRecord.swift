//
//  AudioRecord.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/24/25.
//

import Foundation
import AVFoundation
import SwiftData

struct Recording: Identifiable, Hashable {
    let fileURL: URL
    let createdAt: Date
    let duration: TimeInterval

    var id: URL {
        fileURL.standardizedFileURL
    }
    
    var title: String {
        return fileURL.deletingPathExtension().lastPathComponent
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 a h시 m분"
        return formatter.string(from: createdAt)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)분 \(seconds)초"
    }
}

class AudioRecorder: ObservableObject {
    @Published var recordings: [Recording] = []
    
    private var recorder: AVAudioRecorder?
    private var startTime: Date?
    
    func start() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let url = getFileURL()
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            startTime = Date()
        } catch {
            print("녹음 실패: \(error)")
        }
    }
    
    func pause() {
        recorder?.pause()
    }
    
    func resume() {
        recorder?.record()
    }
    
    func stop() {
        recorder?.stop()
        if let url = recorder?.url {
            let duration = getAccurateAudioDuration(from: url)
            let recording = Recording(fileURL: url, createdAt: Date(), duration: duration)
            recordings.append(recording)
        }
    }
    
    /// m4a 파일에서 실제 재생 길이 측정
    private func getAccurateAudioDuration(from url: URL) -> TimeInterval {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            print("오디오 파일 길이 측정 실패: \(error)")
            return 0
        }
    }

    private func getFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "Recording_\(formatter.string(from: Date())).m4a"
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return path.appendingPathComponent(filename)
    }
}

//import Foundation
//import AVFoundation
//
//struct Recording: Identifiable {
//    let id = UUID()
//    let fileURL: URL
//    let createdAt: Date
//    let duration: TimeInterval
//    
//    var title: String {
//        return fileURL.deletingPathExtension().lastPathComponent
//    }
//    
//    var formattedDate: String {
//        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "ko_KR")
//        formatter.dateFormat = "yyyy년 M월 d일 a h시 m분"
//        return formatter.string(from: createdAt)
//    }
//    
//    var formattedDuration: String {
//        let minutes = Int(duration) / 60
//        let seconds = Int(duration) % 60
//        return "\(minutes)분 \(seconds)초"
//    }
//}
//
//class AudioRecorder: ObservableObject {
//    @Published var recordings: [Recording] = []
//
//    private var recorder: AVAudioRecorder?
//    private var startTime: Date?
//    private var accumulatedDuration: TimeInterval = 0
//
//    func start() {
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(.playAndRecord, mode: .default)
//            try audioSession.setActive(true)
//
//            let url = getFileURL()
//            let settings = [
//                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
//                AVSampleRateKey: 12000,
//                AVNumberOfChannelsKey: 1,
//                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
//            ]
//            recorder = try AVAudioRecorder(url: url, settings: settings)
//            recorder?.record()
//            startTime = Date()
//            accumulatedDuration = 0 // reset
//        } catch {
//            print("녹음 실패: \(error)")
//        }
//    }
//
//    func pause() {
//        if let start = startTime {
//            accumulatedDuration += Date().timeIntervalSince(start)
//        }
//        recorder?.pause()
//    }
//
//    func resume() {
//        startTime = Date()
//        recorder?.record()
//    }
//
//    func stop() {
//        if let start = startTime {
//            accumulatedDuration += Date().timeIntervalSince(start)
//        }
//        recorder?.stop()
//        if let url = recorder?.url {
//            let recording = Recording(fileURL: url, createdAt: Date(), duration: accumulatedDuration)
//            recordings.append(recording)
//        }
//    }
//
//    private func getFileURL() -> URL {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyyMMdd_HHmmss"
//        let filename = "Recording_\(formatter.string(from: Date())).m4a"
//        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        return path.appendingPathComponent(filename)
//    }
//}
