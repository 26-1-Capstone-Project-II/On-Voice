//
//  PronunciationAnalysisFixtures.swift
//  OnVoiceTests
//
//  실기기에서 캡처한 자유 발화의 Whisper / Apple ASR 결과를 텍스트 fixture 로
//  보존해 PronunciationScriptAnalysisService 회귀를 추적한다.
//
//  사용 방식:
//   - 실기기에서 발화 → Apple ASR 결과(=intentText)와 Whisper segment 배열을
//     디버그 로그/print 로 캡처
//   - 이 파일의 `allFixtures` 배열에 새 케이스를 추가
//   - PronunciationAnalysisSnapshotTests 가 각 fixture 의 snapshot 을
//     deterministic 값으로 비교 → 회귀 발생 시 diff 가 그대로 보임
//
//  WhisperKit / Apple Speech 실제 호출은 하지 않는다(텍스트 fixture).
//  대신 PronunciationScriptAnalysisService 단계만 직접 구동해 분류/매핑/G2P
//  결과가 변하는지 detection 한다.
//

import Foundation
@testable import OnVoice

/// 단일 발화 케이스. intentText 는 Apple ASR 이 잡은 의도 표기,
/// phoneticSegments 는 Whisper 가 돌려준 segment 배열.
struct AnalysisFixture {
    let name: String
    let intentText: String
    let phoneticSegments: [String]
}

/// 분석 결과를 deterministic 한 비교 가능 표현으로 캡처한 snapshot.
/// 회귀 감지에 필요한 핵심 지표만 들고 있어 G2P 가 음절 단위로 살짝 바뀌어도
/// 카테고리/오류 어절 수준에서 의미 있는 변화가 일어났을 때만 깨진다.
struct AnalysisSnapshot: Equatable {
    let sentences: [SentenceSnapshot]

    struct SentenceSnapshot: Equatable {
        /// 메인 스크립트에서 빨강(.error)으로 색칠된 텍스트 조각들.
        /// 음절 단위 색칠 정책에 따라 1글자씩 들어 있는 경우가 일반적이다.
        let errorTexts: [String]
        /// popup 의 errorTypes 태그(top 3). 순서는 분류기의 빈도 정렬을 따른다.
        let topCategories: [String]
        /// popup 이 노출되는지(=errorDetail nil 여부).
        let hasErrorDetail: Bool
    }

    static func capture(from script: PronunciationErrorScript) -> AnalysisSnapshot {
        let sentenceSnapshots = script.sentences.map { sentence in
            let errorTexts = sentence.segments
                .filter { $0.status == .error }
                .map(\.text)
            let categories = sentence.errorDetail?.errorTypes.map(\.title) ?? []
            return SentenceSnapshot(
                errorTexts: errorTexts,
                topCategories: categories,
                hasErrorDetail: sentence.errorDetail != nil
            )
        }
        return AnalysisSnapshot(sentences: sentenceSnapshots)
    }
}

/// 알려진 fixture 모음. 실기기 검증에서 케이스를 추가할 때마다 여기 append.
enum AnalysisFixtures {

    /// 야구 중계 narration. 2026-05 자유 발화 캡처에서 추출.
    /// 다양한 음운 패턴(연음/경음/비음/탈락) 이 한 segment 안에 섞여 있어
    /// 분류기 회귀 감지에 가장 광범위한 신호를 준다.
    static let baseballNarration = AnalysisFixture(
        name: "baseball-narration",
        intentText:
            "오늘은 키움 히어로즈랑 고척에서 경기를 하는데 아까 사회초까지만 " +
            "해도 쓰리런 치고 솔로포 치고 장난 아니었는데 점수 오 점 먼저 " +
            "냈다고 투수가 막 던져서 지금 오대오 동점이야",
        phoneticSegments: [
            "오늘은 키움 키움휘호르지란 고처 게서 경기를 하는데 아까 사회 " +
            "초까지만 해도 쓰리런 치고 솔로 포치고 장난아니얻낸 데 점수 오 " +
            "전만저네따고 투수가 막떤줘서 지그 모대오 동저미야"
        ]
    )

    /// 단어 내 경음화 누락. 학교 → 학꾜 가 표준인데 사용자가 평음으로 발음.
    /// "교" 음절의 초성만 빨강.
    static let tensificationMissed = AnalysisFixture(
        name: "tensification-missed",
        intentText: "학교",
        phoneticSegments: ["학교"]
    )

    /// 어절 사이 연음 — 사용자가 G2P 표준과 동일하게 연음 적용. 오류 없음.
    /// G2P 가 어절 경계 연음을 인정하는지 회귀 방지용 fixture.
    static let interWordLinkingCorrect = AnalysisFixture(
        name: "inter-word-linking-correct",
        intentText: "고척 에서",
        phoneticSegments: ["고처 게서"]
    )

    /// 음절 누락 케이스. ref 첫 음절이 hyp 에서 빠짐.
    /// 색칠 자리는 없지만 errorDetail 은 popup 안내용으로 보존되어야 한다.
    static let firstSyllableDropped = AnalysisFixture(
        name: "first-syllable-dropped",
        intentText: "안녕하세요",
        phoneticSegments: ["녕하세요"]
    )

    static let all: [AnalysisFixture] = [
        baseballNarration,
        tensificationMissed,
        interWordLinkingCorrect,
        firstSyllableDropped
    ]
}
