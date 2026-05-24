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

struct PhoneticTranscription: Equatable {
    let fullText: String
    let segments: [String]

    static let empty = PhoneticTranscription(fullText: "", segments: [])
}

/// 전사 파이프라인이 실패할 수 있는 분류된 케이스. UI 상에서 단순 빈 결과와
/// 구분해 사용자/디버깅 대상에게 원인을 노출할 수 있도록 한다.
enum TranscriptionFailure: Error, Equatable {
    /// 번들에 mlmodelc(AudioEncoder/TextDecoder/MelSpectrogram)가 누락됐거나
    /// Git LFS pull이 빠져 모델 폴더를 찾지 못한 경우
    case modelMissing
    /// 모델 폴더는 있으나 WhisperKit 초기화(파이프라인 로드) 자체가 실패한 경우
    case pipelineLoadFailed
    /// 모델은 로드됐으나 실제 추론(`transcribe`) 호출이 실패한 경우
    case transcribeFailed
}

actor WhisperPhoneticTranscriptionService {
    enum ServiceError: Error {
        case modelFolderNotFound
        case pipelineUnavailable
    }

    static let shared = WhisperPhoneticTranscriptionService()

    private var pipeline: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    func transcribe(url: URL) async -> Result<PhoneticTranscription, TranscriptionFailure> {
        let pipe: WhisperKit
        do {
            pipe = try await loadPipelineIfNeeded()
        } catch ServiceError.modelFolderNotFound {
            print("WhisperPhoneticTranscriptionService: model folder not found")
            return .failure(.modelMissing)
        } catch {
            print("WhisperPhoneticTranscriptionService: pipeline load failed:", error)
            return .failure(.pipelineLoadFailed)
        }

        do {
            let results = try await pipe.transcribe(
                audioPath: url.path,
                decodeOptions: phoneticDecodeOptions()
            )
            // Whisper의 segment 경계를 보존하면 원본 UI의 문단 구조를 유지할 수 있다.
            // 한 chunk가 통째로 들어오면 마침표가 없는 한국어 발화도 자연스러운 단락이 된다.
            let segments = results
                .flatMap { $0.segments.map(\.text) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let fullText = segments.joined(separator: " ")
            return .success(PhoneticTranscription(fullText: fullText, segments: segments))
        } catch {
            print("WhisperPhoneticTranscriptionService.transcribe error:", error)
            return .failure(.transcribeFailed)
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

    private static let requiredModelComponents = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc",
        "MelSpectrogram.mlmodelc"
    ]

    /// WhisperKitConfig(modelFolder:)이 요구하는 세 mlmodelc(AudioEncoder/TextDecoder/
    /// MelSpectrogram)가 모두 존재하는 폴더만 유효 후보로 본다.
    /// AudioEncoder 하나만 보고 통과시키면 LFS pull 누락 등으로 일부 파일만 있는 경우에도
    /// WhisperKit 초기화가 진행되어 런타임 실패로 이어진다.
    private static func resolveLocalModelFolder() -> URL? {
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "Whisper_CoreML_Model", withExtension: nil),
            bundle.resourceURL?.appendingPathComponent("Whisper_CoreML_Model", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Whisper_CoreML_Model", isDirectory: true)
        ]

        for candidate in candidates {
            guard let url = candidate, containsAllRequiredComponents(at: url) else { continue }
            return url
        }

        // fileSystemSynchronizedGroups은 폴더 구조를 유지하지 않을 수 있어
        // mlmodelc가 번들 루트에 평탄화된 경우도 허용한다. 이때도 세 구성요소가
        // 같은 위치에 모두 있어야 유효 후보로 본다.
        if let audioEncoder = bundle.url(forResource: "AudioEncoder", withExtension: "mlmodelc") {
            let parent = audioEncoder.deletingLastPathComponent()
            if containsAllRequiredComponents(at: parent) {
                return parent
            }
        }

        return nil
    }

    private static func containsAllRequiredComponents(at folder: URL) -> Bool {
        let fileManager = FileManager.default
        return requiredModelComponents.allSatisfy { component in
            fileManager.fileExists(atPath: folder.appendingPathComponent(component).path)
        }
    }
}
