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

    var usesGeneratedDefaultTitle: Bool {
        title.wholeMatch(of: /^Recording_\d{8}_\d{6}$/) != nil
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
    static let shared = AudioRecorder()

    @Published var recordings: [Recording] = []
    
    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    enum RecordingMutationError: LocalizedError {
        case recordingNotFound
        case invalidTitle
        case fileOperationFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .recordingNotFound:
                return "대상 녹음을 찾을 수 없어요."
            case .invalidTitle:
                return "녹음 이름을 다시 확인해 주세요."
            case let .fileOperationFailed(underlying):
                return "파일 작업에 실패했어요. \(underlying.localizedDescription)"
            }
        }
    }
    
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
        guard let recorder else { return }

        let shouldPersistRecording = recorder.isRecording || recorder.currentTime > 0
        recorder.stop()

        if shouldPersistRecording {
            let url = recorder.url
            let duration = getAccurateAudioDuration(from: url)
            let recording = Recording(fileURL: url, createdAt: Date(), duration: duration)
            recordings.append(recording)
        }

        self.recorder = nil
        startTime = nil
    }

    func deleteRecording(_ recording: Recording) throws {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else {
            throw RecordingMutationError.recordingNotFound
        }

        do {
            if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                try FileManager.default.removeItem(at: recording.fileURL)
            }
            recordings.remove(at: index)
        } catch {
            throw RecordingMutationError.fileOperationFailed(underlying: error)
        }
    }

    @discardableResult
    func renameRecording(_ recording: Recording, to newTitle: String) throws -> Recording {
        let sanitizedTitle = Self.sanitizedRecordingTitle(from: newTitle)
        guard !sanitizedTitle.isEmpty else {
            throw RecordingMutationError.invalidTitle
        }

        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else {
            throw RecordingMutationError.recordingNotFound
        }

        let currentNormalizedTitle = Self.sanitizedRecordingTitle(from: recording.title)
        if sanitizedTitle == currentNormalizedTitle {
            return recording
        }

        let destinationURL = uniqueRecordingURL(for: recording, sanitizedTitle: sanitizedTitle)
        guard destinationURL != recording.fileURL else { return recording }

        do {
            try FileManager.default.moveItem(at: recording.fileURL, to: destinationURL)

            let updatedRecording = Recording(
                fileURL: destinationURL,
                createdAt: recording.createdAt,
                duration: recording.duration
            )
            recordings[index] = updatedRecording
            return updatedRecording
        } catch {
            throw RecordingMutationError.fileOperationFailed(underlying: error)
        }
    }

    static func sanitizedRecordingTitle(from rawTitle: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let components = rawTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: invalidCharacters)

        return components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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

    private func uniqueRecordingURL(for recording: Recording, sanitizedTitle: String) -> URL {
        let directoryURL = recording.fileURL.deletingLastPathComponent()
        let fileExtension = recording.fileURL.pathExtension
        var candidateURL = directoryURL.appendingPathComponent(sanitizedTitle).appendingPathExtension(fileExtension)
        var suffix = 2

        while candidateURL != recording.fileURL,
              FileManager.default.fileExists(atPath: candidateURL.path) {
            let disambiguatedTitle = "\(sanitizedTitle) (\(suffix))"
            candidateURL = directoryURL
                .appendingPathComponent(disambiguatedTitle)
                .appendingPathExtension(fileExtension)
            suffix += 1
        }

        return candidateURL
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
