# 발음 분석 리포트 화면 인수인계 문서

## 목적

`나의 발음 분석 리포트` 화면은 녹음 분석 후 사용자의 발음 평가 점수와 사용자가 어려워하는 발음 유형 순위를 보여주는 요약 화면이다. 이 화면 다음 단계가 `오류 발음 스크립트` 상세 화면이다.

현재는 발음 분석 AI 모델이 아직 연결되지 않아 대부분의 내용이 하드코딩되어 있다. 실제 모델 연결 시에는 점수, 코멘트, 어려운 발음 순위, 각 유형별 연습 가이드가 API 응답으로 내려와야 한다.

## 현재 연결 위치

- 화면 파일: `frontend/OnVoice/View/AnalysisSummaryView.swift`
- ViewModel: `frontend/OnVoice/ViewModel/RecordingAnalysisViewModel.swift`
- 분석 모델: `frontend/OnVoice/Model/AnalysisModels.swift`
- 분석 서비스 더미: `frontend/OnVoice/Service/SpeechAnalysisService.swift`

`AnalysisSummaryView`는 `Recording`을 받아 `RecordingAnalysisViewModel`을 생성하고, `.task`에서 `viewModel.loadIfNeeded()`를 호출한다.

## 현재 구현 상태

### 점수

현재 점수 계산:

```swift
private var score: Int {
    guard let analysis = viewModel.analysis, analysis.isPronunciationEvaluationAvailable else {
        return 54
    }

    return Int((analysis.overallAccuracy * 100).rounded())
}
```

- `analysis.isPronunciationEvaluationAvailable == true`이면 `overallAccuracy * 100`을 점수로 사용한다.
- 현재 `SpeechAnalysisService.analyze()`는 `isPronunciationEvaluationAvailable: false`를 반환한다.
- 따라서 실제 화면에서는 항상 `54점`이 fallback으로 표시된다.

### 점수 등급 문구

점수에 따라 `PronunciationScoreLevel`에서 문구와 색상을 결정한다.

- `0...35`: `연습이 조금 필요해요.`
- `36...70`: `조금 더 또박또박 말해볼까요?`
- `71...100`: `발음이 자연스럽고 안정적이예요!`

현재 54점 fallback이므로 기본적으로 중간 등급 문구가 표시된다.

### 점수 카드 설명 문구

현재 아래 문구는 API가 아니라 화면 내부에 하드코딩되어 있다.

```swift
Text("받침 발음을 가장 어려워하고 있어요.\n목소리에 힘을 주고, 단어를 끝까지 소리낸다는\n방식으로 발음을 연습해보면 좋을 것 같아요.")
```

실제 모델 연결 후에는 사용자의 1위 오류 유형과 분석 코멘트를 기반으로 내려받아야 한다.

### 내가 어려워하는 발음 순위

현재 순위 목록은 `PronunciationDifficultyItem.samples`를 그대로 사용한다.

```swift
private var difficultyItems: [PronunciationDifficultyItem] {
    PronunciationDifficultyItem.samples
}
```

현재 하드코딩된 샘플:

1. `종성 오류`
   - subtitle: `받침 소리가 부정확해요`
   - guide: `마지막에 입을 닫고 멈추는 것이 중요해요...`
   - accentColor: `#FFA0A0`

2. `된소리/평음/격음 혼동`
   - subtitle: `ㄱ/ㄲ/ㅋ 발음 구분이 어려워요`
   - guide: `소리를 시작할 때 목과 입안의 긴장감을 다르게 느껴보세요...`
   - accentColor: `#FFF79E`

3. `음절 구조 단순화`
   - subtitle: `발음하지 않는 음절이 있어요`
   - guide: `단어를 한 글자씩 나누어 읽고...`
   - accentColor: `#B2B8FF`

각 항목은 탭하면 펼쳐지고, `error_img_1` 이미지와 가이드 문구가 표시된다.

## 현재 분석 서비스 상태 (2026-05-27 갱신)

`SpeechAnalysisService.analyze(url:referenceText:)` 는 **온디바이스 Whisper 음운 전사 → Apple ASR + G2P 자모 정렬 → 점수/난이도 산출** 까지 모두 수행한다. 한글 expected 음절이 1개 이상 존재하면 `isPronunciationEvaluationAvailable: true` 로 결과를 돌려준다. 한글 입력이 없거나 권한이 거부된 경우엔 false 로 두고 화면 fallback 을 쓰게 한다.

### 점수 산출 파이프라인 (2026-05-27 추가)

```
SpeechAnalysisService.analyze
 ├─ phoneticService.transcribe(url:)          // Whisper phonetic
 ├─ intentService.transcribe(url:)            // Apple ASR intent text
 ├─ scriptAnalyzer.analyzeArtifacts(...)      // 자모 정렬 + script + cells
 ├─ PronunciationScoreCalculator.compute      // 한글 expected 분모 → 0-100
 ├─ PronunciationDifficultyAggregator.aggregate  // 10종 raw 카테고리 → top 3
 └─ PronunciationSummaryCommentGenerator.generate // 1위 카테고리 → 코멘트
```

- 점수 분모: `cells` 중 `expected != nil` 인 한글 음절 수 (alignHangulOnly 결과라 한글만)
- 점수 분자: 분모 중 `cell.hasError == false` 인 cell (dropout/substitution 모두 오류)
- 카테고리 집계: `PronunciationErrorClassifier.classify` 를 cell 마다 호출, 빈도 합산 후 사전순 안정 정렬, 상위 3개
- 요약 코멘트: 1위 카테고리에 매핑된 문구. 분류 결과가 없으면 등급(low/middle/high) 기반 fallback
- 사람 아이콘: 카테고리별 디자인 자산이 확정될 때까지 모두 `error_img_1` fallback. 매핑은 별도 후속 이슈에서 진행.

## 이전 분석 서비스 상태 (2026-05 초기 갱신)

> 아래 블록은 점수 산출이 미구현이던 시점의 상태. 변경 사항 추적용으로 남겨둔다.

```swift
final class SpeechAnalysisService {
    init(
        transcriptionService: WhisperPhoneticTranscriptionService = .shared,
        scriptAnalyzer: PronunciationScriptAnalyzing = PronunciationScriptAnalysisService()
    ) { ... }

    func analyze(url: URL, referenceText: String? = nil) async -> AnalysisResult {
        // 1) 소리나는 대로 전사 (segment 단위로 다문단 보존)
        let transcription = await transcriptionService.transcribe(url: url)
        // 2) Whisper segment를 그대로 문단으로 옮긴 raw 스크립트
        let rawScript = PronunciationErrorScript.makePlainScript(from: transcription.segments)
        // 3) 분석 단계 (현재는 stub → 입력 그대로 반환, DEBUG 빌드는 데모 errorDetail 주입)
        let analyzedScript = await scriptAnalyzer.analyze(script: rawScript, referenceText: referenceText)

        return AnalysisResult(
            transcript: transcription.fullText,
            standardText: referenceText ?? "",
            standardPronunciation: "",
            sentences: [],
            overallAccuracy: 0,
            isPronunciationEvaluationAvailable: false,
            scriptAnalysis: analyzedScript
        )
    }
}
```

즉 현재 구현된 부분은 **전사 → 스크립트 변환 → 다음 화면 전달** 까지이며, 점수/난이도 순위/오류 검출은 비어 있다. 점수가 비어 있으므로 요약 화면은 여전히 fallback 54점을 표시한다.

## 필요한 API 요약

요약 화면에는 최소 1개의 분석 API가 필요하다.

### `POST /api/v1/pronunciation/analysis`

녹음 파일을 업로드하면 발음 점수, 어려운 발음 순위, 오류 스크립트 상세 데이터를 반환한다.

요청 예시:

```http
POST /api/v1/pronunciation/analysis
Content-Type: multipart/form-data
```

필드:

- `audio`: 녹음 파일
- `referenceText`: 선택. 기준 스크립트가 있을 경우 전달
- `locale`: 예: `ko-KR`

응답 예시:

```json
{
  "analysisId": "analysis-20260522-001",
  "overallAccuracy": 0.54,
  "score": 54,
  "scoreLevel": "middle",
  "summaryTitle": "조금 더 또박또박 말해볼까요?",
  "summaryComment": "받침 발음을 가장 어려워하고 있어요.\n목소리에 힘을 주고, 단어를 끝까지 소리낸다는\n방식으로 발음을 연습해보면 좋을 것 같아요.",
  "difficultyItems": [
    {
      "id": "final-consonant",
      "rank": 1,
      "title": "종성 오류",
      "subtitle": "받침 소리가 부정확해요",
      "practiceTitle": "ㅁ, ㅂ, ㅍ, ㅃ 받침의 발음",
      "guideText": "마지막에 입을 닫고 멈추는 것이 중요해요.\n입술 또는 혀를 붙이고 끊어주세요.",
      "accentColor": "#FFA0A0",
      "imageName": "error_img_1",
      "errorCount": 7,
      "accuracy": 0.42
    }
  ],
  "scriptAnalysis": {
    "sentences": []
  }
}
```

필드 설명:

- `overallAccuracy`: 0.0부터 1.0 사이의 전체 발음 정확도
- `score`: 0부터 100 사이 점수. 클라이언트 계산 대신 서버가 내려줘도 된다.
- `scoreLevel`: `low`, `middle`, `high`
- `summaryTitle`: 점수 카드 제목. 없으면 클라이언트가 점수 기반으로 fallback 가능
- `summaryComment`: 점수 카드 설명 문구
- `difficultyItems`: 사용자가 어려워하는 발음 유형 순위. 최대 3개 권장
- `scriptAnalysis`: 다음 화면인 오류 발음 스크립트에서 사용할 문장 단위 상세 분석

## 클라이언트 모델 현황 및 제안

현재 `AnalysisResult`는 스크립트 분석 결과까지는 담을 수 있도록 확장되었다(`scriptAnalysis: PronunciationErrorScript`). 다만 점수/난이도 순위 표현용 필드는 아직 없으므로 다음 확장이 권장된다.

현재 정의:

```swift
struct AnalysisResult {
    let transcript: String
    let standardText: String
    let standardPronunciation: String
    let sentences: [AnalysisSentence]
    let overallAccuracy: Double
    let isPronunciationEvaluationAvailable: Bool
    let scriptAnalysis: PronunciationErrorScript   // 신규 추가, 기본값 .empty
}
```

요약 화면이 실제 점수/순위 데이터를 받기 시작하면 다음 필드를 추가하는 것이 좋다.

```swift
struct AnalysisResult {
    let analysisId: String
    let transcript: String
    let standardText: String
    let standardPronunciation: String
    let sentences: [AnalysisSentence]
    let overallAccuracy: Double
    let score: Int
    let scoreLevel: PronunciationScoreLevelResult
    let summaryTitle: String
    let summaryComment: String
    let difficultyItems: [PronunciationDifficultyResult]
    let isPronunciationEvaluationAvailable: Bool
    let scriptAnalysis: PronunciationErrorScript
}

struct PronunciationDifficultyResult: Identifiable {
    let id: String
    let rank: Int
    let title: String
    let subtitle: String
    let practiceTitle: String
    let guideText: String
    let accentColorHex: String
    let imageName: String?
    let errorCount: Int
    let accuracy: Double
}

enum PronunciationScoreLevelResult: String {
    case low
    case middle
    case high
}
```

## 화면 매핑 방식

실제 API 연결 후 `AnalysisSummaryView`는 다음 순서로 바뀌면 된다.

- `score`: `analysis.score` 또는 `analysis.overallAccuracy * 100`
- `scoreLevel.title`: `analysis.summaryTitle` 우선, 없으면 기존 점수 기반 fallback
- 점수 카드 설명: 현재 하드코딩 문구 대신 `analysis.summaryComment`
- `difficultyItems`: `PronunciationDifficultyItem.samples` 대신 `analysis.difficultyItems`
- 색상: `accentColorHex`를 `Color(hex:)`로 변환
- 이미지: 서버에서 내려준 `imageName`이 없으면 기본 이미지 `error_img_1` 사용

## 오류 발음 스크립트 화면과의 관계

요약 화면의 `오류 발음 확인하기` 버튼은 상세 화면으로 이동한다.

상세 화면에서 필요한 데이터는 별도 문서에 정리되어 있다.

- `docs/pronunciation-error-script-handoff.md`

권장 방식은 분석 API 응답에 요약 데이터와 상세 스크립트 데이터를 함께 포함하는 것이다. 그러면 요약 화면과 상세 화면이 같은 `analysisId`와 같은 문장 ID를 공유할 수 있다.

## 남은 작업

완료:
- [x] `SpeechAnalysisService` 가 온디바이스 Whisper 음운 전사를 수행하고 `scriptAnalysis` 를 채움
- [x] `AnalysisResult.scriptAnalysis` 필드 추가
- [x] 상세 화면으로 `scriptAnalysis` 데이터를 전달 (`AnalysisSummaryView` → `PronunciationErrorScriptView`)
- [x] 점수/난이도 산출 알고리즘 (`PronunciationScoreCalculator`, `PronunciationDifficultyAggregator`, `PronunciationSummaryCommentGenerator`)
- [x] `AnalysisResult` 에 `score`, `scoreLevel`, `summaryComment`, `difficultyItems` 필드 추가
- [x] `PronunciationScriptAnalysisService` 가 cells/expectedAll 까지 포함한 `PronunciationAnalysisArtifacts` 를 반환

미완:
- [ ] `PronunciationDifficultyItem.samples` 하드코딩 제거 → `analysis.difficultyItems` 사용 (sub-issue 2)
- [ ] 점수 카드 설명 문구 (`AnalysisSummaryView` 내 하드코딩) 를 `analysis.summaryComment` 로 교체 (sub-issue 2)
- [ ] 카테고리별 사람 아이콘 매핑 — 현재 모두 `error_img_1` fallback (sub-issue 3)
- [ ] 분석 실패/진행 중/분석 불가 상태 UI 정리 (현재 Whisper 로드 실패는 `print` 후 빈 결과 반환)
- [ ] 백엔드 API 연동 여부 결정 (현재는 모든 처리가 온디바이스)

