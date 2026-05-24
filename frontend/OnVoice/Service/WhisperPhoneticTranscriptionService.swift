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

/// 전사 파이프라인이 정상적인 success(=비어있지 않은 transcription)를 돌려주지
/// 못한 모든 경우를 분류해 표현한다. success 타입은 "항상 비어있지 않다"는
/// 불변식을 갖도록 해, UI/로그가 단순 빈 결과와 실패를 구분할 수 있게 한다.
enum TranscriptionFailure: Error, Equatable {
    /// 번들에 mlmodelc(AudioEncoder/TextDecoder/MelSpectrogram)가 누락됐거나
    /// Git LFS pull이 빠져 모델 폴더를 찾지 못한 경우
    case modelMissing
    /// 모델 폴더는 있으나 WhisperKit 초기화(파이프라인 로드) 자체가 실패한 경우
    case pipelineLoadFailed
    /// 모델은 로드됐으나 실제 추론(`transcribe`) 호출이 실패한 경우
    case transcribeFailed
    /// 추론은 성공했지만 segment가 0개로 돌아온 경우(무음/노이즈/너무 짧은 클립).
    /// 기술적 실패가 아닌 informational 분류이며, UI는 "다시 녹음해 주세요" 톤으로
    /// 노출한다. 이 케이스를 success(빈 결과)로 흘려보내면 사용자도 개발자도
    /// 모델 로드 실패와 구분할 수 없으므로 명시적으로 failure 사이드에 둔다.
    case noSpeechDetected
}

actor WhisperPhoneticTranscriptionService {
    enum ServiceError: Error {
        case modelFolderNotFound
        case pipelineUnavailable
    }

    static let shared = WhisperPhoneticTranscriptionService()

    private var pipeline: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    /// 앱 부팅 시점에 한 번 호출해 mlmodelc 로드 + CoreML 그래프 컴파일 +
    /// ANE shader 생성의 콜드 스타트 비용을 미리 치른다. 실패해도 silently 흘려보내며,
    /// 실제 transcribe 호출에서 다시 시도된다(거기서 실패 사유가 UI 로 표면화).
    func prewarm() async {
        _ = try? await loadPipelineIfNeeded()
    }

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

            // segment가 0개면 success로 흘려보내지 않는다. 무음/노이즈/너무 짧은
            // 클립 등 의미 있는 발화가 잡히지 않은 케이스이며, UI/로그가 모델 로드
            // 실패 같은 critical 케이스와 구분해 처리할 수 있도록 명시적 failure로
            // 매핑한다. success 타입은 항상 비어있지 않다는 불변식을 보장한다.
            guard !segments.isEmpty else {
                print("WhisperPhoneticTranscriptionService: transcribe returned no segments")
                return .failure(.noSpeechDetected)
            }

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
