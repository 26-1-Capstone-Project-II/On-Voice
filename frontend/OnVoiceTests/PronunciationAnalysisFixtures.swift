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

    /// segment 경계 gap 시나리오 (자연어): ref "안녕하세요 잘있나요" 인데 hyp 가 두
    /// segment ["안녕", "잘있나요"] 로 끊겨 사이의 "하세요" 가 expected-only gap.
    /// 검증은 segment 분배 결과(hasErrorDetail) 만 — G2P 가 "잘있" 부분에 변환을 일으켜
    /// errorTexts 가 부수적으로 채워질 수 있어 그 값은 검증하지 않는다.
    static let boundaryGapSplit = AnalysisFixture(
        name: "boundary-gap-split",
        intentText: "안녕하세요 잘있나요",
        phoneticSegments: ["안녕", "잘있나요"]
    )

    /// segment 경계 gap 분배 검증용 단순 fixture (G2P 변환 영향 없음).
    /// ref "가나다라마바사" (받침 없는 음절만) 를 hyp ["가나", "바사"] 로 끊으면
    /// 가운데 "다라마" 가 expected-only gap.
    /// ref-distance 정책: "다"(exp=2, prev=1·next=5, dist 1·3) → segment 0,
    ///                    "라"(exp=3, dist 2·2, 동률→prev) → segment 0,
    ///                    "마"(exp=4, dist 3·1) → segment 1.
    /// 두 segment 모두 누락 음절을 받고, errorTexts 는 둘 다 비어야 한다.
    /// 이전 lastSegment 정책은 "다/라/마" 가 모두 segment 0 에 몰렸다.
    static let boundaryGapSplitSimple = AnalysisFixture(
        name: "boundary-gap-split-simple",
        intentText: "가나다라마바사",
        phoneticSegments: ["가나", "바사"]
    )

    /// 연음 오류이지만 ASR 이 hyp 종성을 잘못 잡은 케이스. ref "음악" → G2P "으막"
    /// 인데 hyp 가 "응악" 으로 종성 ㅇ 을 듣는다. strict 매칭(받침 자모 ↔ 다음 ref
    /// 초성) 은 실패하지만, 약한 시그니처 fallback 으로 종성 연음화 카테고리로
    /// 분류되어야 한다. (이전엔 dropout 으로 흡수됐던 케이스)
    static let linkingMisrecognized = AnalysisFixture(
        name: "linking-asr-misrecognized",
        intentText: "음악",
        phoneticSegments: ["응악"]
    )

    static let all: [AnalysisFixture] = [
        baseballNarration,
        tensificationMissed,
        interWordLinkingCorrect,
        firstSyllableDropped,
        boundaryGapSplit,
        boundaryGapSplitSimple,
        linkingMisrecognized
    ]
}
