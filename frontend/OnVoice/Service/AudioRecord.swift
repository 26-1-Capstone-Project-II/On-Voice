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
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: createdAt)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h시 m분"
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
    static let maxRecordingTitleLength = 16

    @Published var recordings: [Recording] = []
    
    private var recorder: AVAudioRecorder?
    private let recordingsDirectoryURL: URL
    private var startTime: Date?
    private var pendingStart: DispatchWorkItem?
    // 워밍업 워크아이템이 실제 record()를 부르기 전 토큰을 비교해, 워밍업 도중
    // pause/stop/새 start()가 일어나면 이전 워크아이템은 자동 무효화한다.
    // DispatchWorkItem.cancel()이 실행 직전 작업을 막지 못하는 레이스를 보강한다.
    private var pendingStartToken: UUID?

    // 마이크 입력 파이프라인이 안정화되기 전 구간(초기 클릭, AGC 릴리즈 등)이
    // 모델에 들어가지 않도록 record() 호출 전에 비워두는 슬립 시간.
    private static let warmupDelay: TimeInterval = 0.15
    private static let recordingFileExtensions: Set<String> = ["wav"]

    init(
        recordingsDirectoryURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    ) {
        self.recordingsDirectoryURL = recordingsDirectoryURL
        createRecordingsDirectoryIfNeeded()
        loadPersistedRecordings()
    }

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
            // .measurement 모드는 iOS의 자동 게인/에코 캔슬/노이즈 서프레션을 끈다.
            // Whisper(파인튜닝)는 가공되지 않은 원시 음성을 가정하므로
            // 일반 통화용 신호처리가 들어가면 음운 변별 정보가 깨진다.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setActive(true)

            let url = getFileURL()
            // Whisper(파인튜닝 포함)은 16 kHz mono 16-bit PCM에서 훈련/검증되었다.
            // 압축(AAC) 없이 동일한 입력을 보장해야 음운 전사 품질이 유지된다.
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            recorder = newRecorder

            // 워밍업 윈도우 동안 stop()/pause()/새 start()가 들어오면 record() 호출을
            // 무효화해야 한다. DispatchWorkItem.cancel()은 실행 직전의 작업을 막지 못하므로
            //   1) pendingStartToken과의 일치 여부로 cancel/replace 케이스 차단
            //   2) recorder identity 비교로 stop() 직후 다른 인스턴스가 들어선 케이스 차단
            // 두 가지를 함께 적용해야 빈 녹음 파일이 잘못 영구화되지 않는다.
            let token = UUID()
            pendingStartToken = token
            let work = DispatchWorkItem { [weak self, weak newRecorder] in
                guard let self else { return }
                guard self.pendingStartToken == token else { return }
                guard let newRecorder, self.recorder === newRecorder else { return }
                newRecorder.record()
                self.startTime = Date()
                self.pendingStart = nil
                self.pendingStartToken = nil
            }
            pendingStart = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.warmupDelay, execute: work)
        } catch {
            print("녹음 실패: \(error)")
        }
    }
    
    func pause() {
        pendingStart?.cancel()
        pendingStart = nil
        pendingStartToken = nil
        recorder?.pause()
    }

    func resume() {
        recorder?.record()
    }

    func stop() {
        pendingStart?.cancel()
        pendingStart = nil
        pendingStartToken = nil

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

    func deleteAllRecordings() throws {
        var remainingRecordings: [Recording] = []
        var firstFailure: Error?

        for recording in recordings {
            do {
                if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                    try FileManager.default.removeItem(at: recording.fileURL)
                }
            } catch {
                remainingRecordings.append(recording)
                firstFailure = firstFailure ?? error
            }
        }

        recordings = remainingRecordings

        if let firstFailure {
            throw RecordingMutationError.fileOperationFailed(underlying: firstFailure)
        }
    }

    @discardableResult
    func renameRecording(_ recording: Recording, to newTitle: String) throws -> Recording {
        let sanitizedTitle = Self.sanitizedRecordingTitle(from: newTitle)
        guard !sanitizedTitle.isEmpty else {
            throw RecordingMutationError.invalidTitle
        }
        let limitedTitle = Self.limitedRecordingTitle(sanitizedTitle)

        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else {
            throw RecordingMutationError.recordingNotFound
        }

        let currentNormalizedTitle = Self.sanitizedRecordingTitle(from: recording.title)
        if limitedTitle == currentNormalizedTitle {
            return recording
        }

        let destinationURL = uniqueRecordingURL(for: recording, sanitizedTitle: limitedTitle)
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

    static func limitedRecordingTitle(_ title: String) -> String {
        String(title.prefix(maxRecordingTitleLength))
    }

    private func loadPersistedRecordings() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: recordingsDirectoryURL,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            recordings = fileURLs
                .filter { Self.recordingFileExtensions.contains($0.pathExtension.lowercased()) }
                .map { url in
                    Recording(
                        fileURL: url,
                        createdAt: persistedCreatedAt(for: url),
                        duration: getAccurateAudioDuration(from: url)
                    )
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("저장된 녹음 목록을 불러오지 못했어요: \(error)")
            recordings = []
        }
    }
    
    /// 녹음 파일에서 실제 재생 길이 측정 (.wav PCM 등)
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
        let filename = "Recording_\(formatter.string(from: Date())).wav"
        createRecordingsDirectoryIfNeeded()
        return recordingsDirectoryURL.appendingPathComponent(filename)
    }

    private func createRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: recordingsDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("녹음 저장 폴더를 준비하지 못했어요: \(error)")
        }
    }

    private func persistedCreatedAt(for url: URL) -> Date {
        if let dateFromGeneratedName = Self.generatedRecordingDate(from: url) {
            return dateFromGeneratedName
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            return resourceValues.creationDate ?? resourceValues.contentModificationDate ?? Date.distantPast
        } catch {
            return Date.distantPast
        }
    }

    private static func generatedRecordingDate(from url: URL) -> Date? {
        let filename = url.deletingPathExtension().lastPathComponent
        guard filename.wholeMatch(of: /^Recording_\d{8}_\d{6}$/) != nil else {
            return nil
        }

        let rawDate = String(filename.dropFirst("Recording_".count))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.date(from: rawDate)
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
