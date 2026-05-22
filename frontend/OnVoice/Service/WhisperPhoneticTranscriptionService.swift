//
//  WhisperPhoneticTranscriptionService.swift
//  OnVoice
//
//  소리나는 대로(phonetic) 한국어 전사를 수행하는 서비스.
//  Voice-Model-Test 저장소에서 추출한 fine-tuned Whisper-tiny CoreML 모델을
//  WhisperKit으로 로드해 온디바이스로 추론한다.
//

import Foundation
import WhisperKit

actor WhisperPhoneticTranscriptionService {
    enum ServiceError: Error {
        case modelFolderNotFound
        case pipelineUnavailable
    }

    static let shared = WhisperPhoneticTranscriptionService()

    private var pipeline: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    func transcribe(url: URL) async -> String {
        do {
            let pipe = try await loadPipelineIfNeeded()
            let results = try await pipe.transcribe(
                audioPath: url.path,
                decodeOptions: phoneticDecodeOptions()
            )
            return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("WhisperPhoneticTranscriptionService.transcribe error:", error)
            return ""
        }
    }

    // MARK: - Pipeline

    private func loadPipelineIfNeeded() async throws -> WhisperKit {
        if let pipeline { return pipeline }

        if let loadTask {
            return try await loadTask.value
        }

        let task = Task<WhisperKit, Error> {
            guard let modelFolder = Self.resolveLocalModelFolder() else {
                throw ServiceError.modelFolderNotFound
            }

            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            return try await WhisperKit(config)
        }
        loadTask = task

        do {
            let pipe = try await task.value
            pipeline = pipe
            loadTask = nil
            return pipe
        } catch {
            loadTask = nil
            throw error
        }
    }

    private func phoneticDecodeOptions() -> DecodingOptions {
        // Voice-Model-Test 저장소의 Python 평가 파이프라인은 `transformers.generate(
        //   max_new_tokens=256, language="ko", task="transcribe")` 기본값으로 그리디
        // 디코딩만 한다. fallback/threshold가 LoRA 출력 분포를 잘못 판단해 word salad를
        // 만들지 않도록 같은 조건을 재현한다.
        DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "ko",
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.0,
            temperatureFallbackCount: 0,
            sampleLength: 256,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            suppressBlank: false,
            compressionRatioThreshold: nil,
            logProbThreshold: nil,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: nil,
            chunkingStrategy: nil
        )
    }

    private static func resolveLocalModelFolder() -> URL? {
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "Whisper_CoreML_Model", withExtension: nil),
            bundle.resourceURL?.appendingPathComponent("Whisper_CoreML_Model", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Whisper_CoreML_Model", isDirectory: true)
        ]

        for candidate in candidates {
            guard let url = candidate else { continue }
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("AudioEncoder.mlmodelc").path) {
                return url
            }
        }

        // fileSystemSynchronizedGroups은 폴더 구조를 유지하지 않을 수 있어
        // mlmodelc가 번들 루트에 평탄화된 경우도 허용한다.
        if let audioEncoder = bundle.url(forResource: "AudioEncoder", withExtension: "mlmodelc") {
            return audioEncoder.deletingLastPathComponent()
        }

        return nil
    }
}
