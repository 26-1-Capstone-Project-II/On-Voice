//
//  WhisperPhoneticTranscriptionService.swift
//  OnVoice
//
//  소리나는 대로(phonetic) 한국어 전사를 수행하는 서비스.
//  Voice-Model-Test 저장소에서 추출한 fine-tuned Whisper-tiny CoreML 모델을
//  WhisperKit으로 로드해 온디바이스로 추론한다.
//

import Foundation
import OSLog
import WhisperKit

private let logger = Logger(subsystem: "com.onvoice", category: "whisper-phonetic")

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
    /// ANE shader 생성의 콜드 스타트 비용을 미리 치른다. prewarm 실패는 치명적이지 않다
    /// — 실제 transcribe 호출에서 다시 시도되고, 거기서 실패 사유가 UI 로 표면화된다.
    /// 다만 디버깅을 위해 실패는 로그로 남긴다.
    func prewarm() async {
        do {
            _ = try await loadPipelineIfNeeded()
        } catch {
            logger.error("prewarm failed: \(String(describing: error), privacy: .private)")
        }
    }

    func transcribe(url: URL) async -> Result<PhoneticTranscription, TranscriptionFailure> {
        let pipe: WhisperKit
        do {
            pipe = try await loadPipelineIfNeeded()
        } catch ServiceError.modelFolderNotFound {
            logger.error("model folder not found")
            return .failure(.modelMissing)
        } catch {
            logger.error("pipeline load failed: \(String(describing: error), privacy: .private)")
            return .failure(.pipelineLoadFailed)
        }

        do {
            let results = try await pipe.transcribe(
                audioPath: url.path,
                decodeOptions: phoneticDecodeOptions()
            )
            // Whisper의 segment 경계를 보존하면 원본 UI의 문단 구조를 유지할 수 있다.
            // 한 chunk가 통째로 들어오면 마침표가 없는 한국어 발화도 자연스러운 단락이 된다.
            // sanitize 단계는 fine-tuned BPE 디코더가 가끔 흘리는 고아 자모/대체문자
            // (□ "tofu" 박스로 보이는 글리프) 를 걸러 화면/분석 양쪽이 같은 한글만 본다.
            let segments = results
                .flatMap { $0.segments.map(\.text) }
                .map(Self.sanitizePhoneticOutput(_:))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // segment가 0개면 success로 흘려보내지 않는다. 무음/노이즈/너무 짧은
            // 클립 등 의미 있는 발화가 잡히지 않은 케이스이며, UI/로그가 모델 로드
            // 실패 같은 critical 케이스와 구분해 처리할 수 있도록 명시적 failure로
            // 매핑한다. success 타입은 항상 비어있지 않다는 불변식을 보장한다.
            guard !segments.isEmpty else {
                logger.info("transcribe returned no segments")
                return .failure(.noSpeechDetected)
            }

            let fullText = segments.joined(separator: " ")
            return .success(PhoneticTranscription(fullText: fullText, segments: segments))
        } catch {
            logger.error("transcribe error: \(String(describing: error), privacy: .private)")
            return .failure(.transcribeFailed)
        }
    }

    // MARK: - Output sanitation

    /// Whisper 출력에서 한국어 글리프로 합쳐지지 못한 자모·대체문자·제어문자를
    /// 걸러낸다. fine-tuned Whisper-tiny 의 BPE 디코더가 가끔 한 음절을 두 개의
    /// modern jamo 토큰으로 흘리는데, 이게 NFC 로 합쳐지지 못하면 폰트가 못 그리는
    /// "tofu" 박스(□) 로 표시된다. 이 단계에서 다음을 수행한다:
    ///
    ///   1) NFC 정규화 (인접한 modern jamo 가 음절로 합쳐질 수 있으면 합친다)
    ///   2) 합쳐지지 못한 고아 자모(U+1100..U+11FF, U+3130..U+318F) 제거
    ///   3) Unicode Replacement Character(U+FFFD) 제거
    ///   4) 제어/포맷/private use scalar 제거 (단 \t, \n 은 보존)
    ///
    /// 한글 음절(U+AC00..U+D7A3) 과 ASCII / 일반 구두점은 그대로 통과.
    /// 점수 산출은 한글 음절 수가 분모라 본 필터로 데이터 손실이 없다.
    /// 또한 `internal` 로 노출되어 단위 테스트가 직접 호출 가능하다.
    static func sanitizePhoneticOutput(_ text: String) -> String {
        let normalized = text.precomposedStringWithCanonicalMapping
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(normalized.unicodeScalars.count)
        for scalar in normalized.unicodeScalars where isAllowedPhoneticScalar(scalar) {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    private static func isAllowedPhoneticScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value

        // 명시적 차단 — tofu/replacement/private use/surrogates
        if value == 0xFFFD { return false }
        if (0xD800...0xDFFF).contains(value) { return false }
        if (0xE000...0xF8FF).contains(value) { return false }

        // 고아 자모 차단 — NFC 후에도 남은 modern/compatibility jamo
        if (0x1100...0x11FF).contains(value) { return false }
        if (0x3130...0x318F).contains(value) { return false }
        if (0xA960...0xA97F).contains(value) { return false }   // Hangul Jamo Extended-A
        if (0xD7B0...0xD7FF).contains(value) { return false }   // Hangul Jamo Extended-B

        // 일반 카테고리 — 제어/포맷 차단 (단 \t, \n 은 보존)
        if value == 0x09 || value == 0x0A { return true }
        switch scalar.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator:
            return false
        default:
            return true
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
