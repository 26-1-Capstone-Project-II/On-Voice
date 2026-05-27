# 오류 발음 스크립트 화면 인수인계 문서

## 목적

`오류 발음 스크립트` 화면은 발음 평가 점수 화면 다음에 이어지는 상세 연습 화면이다. 사용자는 전체 발화 스크립트에서 오류가 난 문장을 확인하고, 해당 문장을 눌러 하단 팝업에서 올바른 발음과 본인의 발음 오류를 비교한 뒤 다시 녹음하며 연습한다.

상태 (2026-05): 1단계(스크립트 출력)가 온디바이스 Whisper 음운 전사로 연결되어 사용자가 실제로 녹음한 발화가 화면에 표시된다. 2단계(자모 단위 오류 검출)는 아직 구현 전이며, `PronunciationScriptAnalysisService` stub이 분석 슬롯을 잡고 있고 DEBUG 빌드에서는 첫 문장에 데모 errorDetail을 주입해 popup card 골격을 시각적으로 확인할 수 있다.

## 현재 연결 위치

- 화면 파일: `frontend/OnVoice/View/PronunciationErrorScriptView.swift`
- 데이터 모델: `frontend/OnVoice/Model/PronunciationScript.swift` (예전 private 타입을 외부 주입 가능하도록 승격)
- 전사 서비스: `frontend/OnVoice/Service/WhisperPhoneticTranscriptionService.swift` (actor 싱글톤, 번들 내 mlmodelc 로드)
- 분석 슬롯: `frontend/OnVoice/Service/PronunciationScriptAnalysisService.swift` (현재 stub, 2단계에서 본문 교체)
- 진입 위치: `frontend/OnVoice/View/AnalysisSummaryView.swift` — `오류 발음 확인하기` 버튼이 `viewModel.analysis?.scriptAnalysis` 를 본 화면으로 전달
- 요약 화면과 필요한 API는 `docs/pronunciation-analysis-summary-handoff.md`에 별도로 정리되어 있다.

## 현재 구현된 플로우

1. 기본 화면
   - 전체 발화 스크립트를 표시한다.
   - 발음 오류가 난 글자 또는 구간은 빨간색으로 표시한다.
   - 오류가 포함된 문장만 탭 가능하다.

2. 오류 문장 클릭
   - 선택된 오류 문장에 해당하는 하단 팝업이 열린다.
   - 팝업이 열린 상태에서는 선택된 문장만 opacity 100%로 유지하고, 다른 문장은 opacity 50%로 표시한다.
   - 같은 오류 문장을 다시 누르면 팝업이 닫히고 선택 상태가 초기화된다.

3. 하단 팝업
   - 오류 유형 태그를 최대 3개까지 표시한다.
   - `내가 어려워하는 발음`으로 지정된 오류 유형은 강조색으로 표시한다.
   - 원래 오류 문장, 올바른 발음, 사용자가 처음 발음한 문장을 표시한다.
   - 처음 발음한 문장에서는 틀린 글자만 빨간색으로 표시한다.

4. 발음 연습하기
   - 버튼을 누르면 녹음 중 상태가 된다.
   - 녹음 중에는 버튼 opacity가 50%로 낮아지고, 좌하단에 파형 애니메이션이 표시된다.
   - 버튼을 다시 누르면 녹음이 종료된다.
   - 녹음 종료 후 새 결과를 표시한다.
   - 기존 최초 발음 문장은 계속 남기고 opacity 50%로 표시한다.
   - 새 녹음 결과는 누적하지 않고 최신 결과 하나로 덮어쓴다.
   - 새 결과에서 실패한 발음은 빨간색, 맞은 발음은 파란색으로 표시한다.

## 현재 주요 상태

`PronunciationErrorScriptView` 내부 상태:

```swift
@State private var selectedSentenceID: UUID?
@State private var isRecording = false
@State private var attempts: [PronunciationPracticeAttempt] = []
@State private var nextAttemptIndex = 0
```

- `selectedSentenceID`: 현재 선택된 오류 문장 ID. 값이 있으면 하단 팝업 표시.
- `isRecording`: 녹음 중 여부. 현재는 더미 토글 상태.
- `attempts`: 새 녹음 결과. 현재는 최신 결과 하나만 유지하도록 덮어쓴다.
- `nextAttemptIndex`: 더미 결과를 번갈아 보여주기 위한 인덱스.

## 현재 데이터 구조

데이터 타입은 더 이상 View private이 아니라 `Model/PronunciationScript.swift` 에 공개 타입으로 정의되어 있어 서비스/뷰모델에서 자유롭게 생성할 수 있다.

```swift
struct PronunciationErrorScript: Equatable {
    let sentences: [PronunciationTranscriptSentence]
    static let empty: PronunciationErrorScript
    /// Whisper segment 배열로부터 한 segment = 한 문단(normal segment)으로 매핑
    static func makePlainScript(from segments: [String]) -> PronunciationErrorScript
}

struct PronunciationTranscriptSentence: Identifiable, Equatable {
    let id: UUID
    let segments: [PronunciationTextSegment]
    let errorDetail: PronunciationErrorSentence?
}

struct PronunciationErrorSentence: Identifiable, Equatable {
    let id: UUID
    let originalSegments: [PronunciationTextSegment]
    let correctSegments: [PronunciationTextSegment]
    let userAttemptSegments: [PronunciationTextSegment]
    let errorTypes: [PronunciationErrorType]
    let dummyAttempts: [PronunciationPracticeAttempt]
}

struct PronunciationPracticeAttempt: Identifiable, Equatable {
    let id: UUID
    let segments: [PronunciationTextSegment]
}

struct PronunciationTextSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let status: PronunciationSegmentStatus   // normal | muted | error | success | emphasis
    var color: Color { /* status → Color 매핑 */ }
}
```

## AI 모델 연결 상태

1단계(스크립트 출력)는 **온디바이스 Whisper 음운 전사**로 이미 연결되어 있다.

- `SpeechAnalysisService.analyze(url:)` 가 `WhisperPhoneticTranscriptionService` 를 호출해 segment 단위 phonetic 전사를 만들고, `PronunciationErrorScript.makePlainScript(from:)` 로 다문단 스크립트로 변환한 뒤 `PronunciationScriptAnalysisService` 로 분석 슬롯을 통과시킨다.
- 결과는 `AnalysisResult.scriptAnalysis` 필드에 담겨 `AnalysisSummaryView` → `PronunciationErrorScriptView` 로 전달된다.
- 모델 자체는 Voice-Model-Test 저장소의 fine-tuned Whisper-tiny CoreML (`Whisper_CoreML_Model/`)로, WhisperKit SPM 통해 actor 싱글톤으로 로드된다.

2단계(자모 단위 오류 검출)는 미구현 — `PronunciationScriptAnalysisService.analyze(script:referenceText:)` 본문이 자모 정렬 알고리즘으로 채워지면 동일한 UI 흐름이 자동으로 실제 오류 표시로 전환된다.

권장 데이터 형태:

```swift
struct PronunciationScriptAnalysis {
    let sentences: [PronunciationSentenceAnalysis]
}

struct PronunciationSentenceAnalysis {
    let id: UUID
    let displaySegments: [PronunciationSegment]
    let errorDetail: PronunciationSentenceErrorDetail?
}

struct PronunciationSentenceErrorDetail {
    let originalSegments: [PronunciationSegment]
    let correctPronunciationSegments: [PronunciationSegment]
    let initialUserPronunciationSegments: [PronunciationSegment]
    let errorTypes: [PronunciationErrorTypeResult]
}

struct PronunciationPracticeResult {
    let sentenceID: UUID
    let recognizedSegments: [PronunciationSegment]
    let isCorrect: Bool
    let score: Double?
}

struct PronunciationSegment {
    let text: String
    let status: PronunciationSegmentStatus
}

enum PronunciationSegmentStatus {
    case normal
    case error
    case success
    case muted
}
```

UI에서는 `status`를 색상으로 매핑하면 된다.

- `normal`: `Color.sub`
- `error`: 빨간색
- `success`: `Color.main`
- `muted`: `Color.gray6`

주의할 점:

- `correctPronunciationSegments`는 올바른 발음 표시용이므로 기본적으로 흰색이어야 한다.
- 파란색은 새 녹음 결과에서 맞은 발음을 표시할 때만 사용한다.
- 처음 녹음된 사용자 발음은 팝업이 열릴 때 항상 표시되어야 한다.
- 새 녹음 결과는 누적하지 않고 최신 1개만 표시한다.

## 실제 녹음 연결 지점

메인 스크립트 전사는 이미 `AudioRecorder` → `SpeechAnalysisService` → `WhisperPhoneticTranscriptionService` 경로로 연결되어 있다. `AudioRecord.swift` 의 녹음 세션은 `.measurement` 모드 + 16 kHz mono 16-bit PCM(.wav) + 150 ms 워밍업으로 Whisper 훈련 입력과 정렬되어 있다.

미연결 부분은 popup card 내부의 **재녹음 연습 버튼**뿐이다. 현재 `toggleDummyPractice()` 가 더미 토글로 남아 있고, 실제 연결 시 다음 방식으로 교체하면 된다.

1. 버튼 첫 클릭
   - `isRecording = true`
   - 마이크 권한 확인
   - 녹음 시작 (`SpeechAnalyzer` 활용 가능)

2. 버튼 두 번째 클릭
   - 녹음 종료
   - `isRecording = false`
   - 녹음 파일을 발음 평가 서비스(`PronunciationAssessmentService` 또는 별도 평가 모델)에 전달
   - 반환된 `PronunciationPracticeResult`를 `attempts = [result]` 형태로 덮어쓰기

실제 모델 연결 후에도 핵심은 `append`가 아니라 최신 결과로 덮어쓰기라는 점이다.

## 모델 담당자에게 요청할 결과 포맷

최소 필요 필드:

- 전체 스크립트 문장 배열
- 각 문장의 표시용 segment 배열
- 문장별 오류 여부
- 오류 문장별 원문
- 오류 문장별 올바른 발음
- 오류 문장별 최초 사용자 발음 segment
- 오류 유형 최대 3개
- 사용자가 어려워하는 오류 유형 여부
- 재녹음 평가 결과 segment

예시 JSON 형태:

```json
{
  "sentences": [
    {
      "id": "sentence-1",
      "segments": [
        { "text": "근데도 저녁 시간 됐다고 ", "status": "normal" },
        { "text": "어떻게", "status": "error" },
        { "text": " 바로 배고프냐.", "status": "normal" }
      ],
      "errorDetail": {
        "originalSegments": [
          { "text": "근데도 저녁 시간 됐다고 어떻게 바로 배고프냐.", "status": "muted" }
        ],
        "correctPronunciationSegments": [
          { "text": "근데도 저녁 시간 됃따고 어떠케 바로 배고프냐.", "status": "normal" }
        ],
        "initialUserPronunciationSegments": [
          { "text": "근데도 저녁 시간 됃따고 ", "status": "normal" },
          { "text": "어떠게", "status": "error" },
          { "text": " 바로 배고프냐.", "status": "normal" }
        ],
        "errorTypes": [
          { "title": "초성 대치", "isDifficult": true },
          { "title": "혼/겹모음 혼동", "isDifficult": false }
        ]
      }
    }
  ]
}
```

재녹음 결과 예시:

```json
{
  "sentenceID": "sentence-1",
  "recognizedSegments": [
    { "text": "근데도 저녁 시간 됃따고 ", "status": "success" },
    { "text": "어떠케", "status": "success" },
    { "text": " 바로 배고프냐.", "status": "success" }
  ],
  "isCorrect": true,
  "score": 0.94
}
```

## 남은 작업

완료:
- [x] 실제 녹음 서비스 연결 (`AudioRecorder` → `SpeechAnalysisService` → WhisperKit)
- [x] 메인 스크립트 전사 데이터 → `AnalysisResult.scriptAnalysis` → 본 화면 전달
- [x] 모델 응답을 화면 데이터 모델(`PronunciationErrorScript`)로 변환
- [x] `script.isEmpty` 일 때의 empty 안내 문구 처리

미완:
- [ ] 자모 단위 오류 검출 알고리즘 (`PronunciationScriptAnalysisService.analyze` 본문)
- [ ] popup card 내 재녹음 연습 버튼 — 더미 토글에서 실제 녹음/평가로 교체
- [ ] 녹음 중 5초 이상 무음 감지 시 자동 종료
- [ ] Whisper 모델 로드 실패 상태를 UI에 명시적으로 노출 (현재는 `print` + `.empty` 반환)
- [ ] 긴 팝업 콘텐츠가 작은 기기에서 잘리지 않도록 높이 정책 조정
- [ ] 빈 상태/전환 스냅샷 또는 뷰 테스트
