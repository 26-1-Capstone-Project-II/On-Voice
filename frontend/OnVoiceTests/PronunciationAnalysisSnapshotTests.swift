//
//  PronunciationAnalysisSnapshotTests.swift
//  OnVoiceTests
//
//  PronunciationAnalysisFixtures 의 각 케이스에 대해 분석 결과 snapshot 을
//  frozen baseline 과 비교한다. 후속 작업이 분류/매핑/G2P 동작을 바꾸면 diff
//  가 즉시 노출되어 의도된 변화 vs 의도하지 않은 회귀를 가시화한다.
//
//  Baseline 갱신 방법:
//   - 의도된 변화로 fixture snapshot 이 바뀌어야 하는 경우, 새 결과를 출력해
//     아래 expected 값에 옮긴 뒤 변화를 PR 설명에 명시한다.
//   - 잠시 expected 갱신이 필요할 때 printSnapshot() helper 로 현재 값을 캡처.
//

import XCTest
@testable import OnVoice

final class PronunciationAnalysisSnapshotTests: XCTestCase {

    private let service = PronunciationScriptAnalysisService()

    // MARK: - Per-fixture snapshots

    func testSnapshot_baseballNarration() async {
        let snapshot = await snapshot(for: AnalysisFixtures.baseballNarration)

        // 야구 narration 은 한 Whisper segment 안에 다양한 오류가 섞여 있어
        // errorDetail 이 반드시 생성되고 카테고리 top 3 가 채워져야 한다.
        XCTAssertEqual(snapshot.sentences.count, 1)
        XCTAssertTrue(snapshot.sentences[0].hasErrorDetail)
        XCTAssertGreaterThan(snapshot.sentences[0].errorTexts.count, 0,
            "분석 결과 어떤 음절도 빨강으로 잡히지 않음 — 분류기/매핑 회귀 의심")
        XCTAssertGreaterThan(snapshot.sentences[0].topCategories.count, 0,
            "errorTypes 가 비어 있음 — 분류기가 결과를 만들지 못함")
        // top category 가 10종 enum 의 raw value 안에 있는지(=새 카테고리 누락 등 회귀 감지)
        let allCategoryTitles = Set(PronunciationErrorCategory.allCases.map(\.rawValue))
        for category in snapshot.sentences[0].topCategories {
            XCTAssertTrue(allCategoryTitles.contains(category),
                "알려지지 않은 카테고리 '\(category)' — enum 추가/오타?")
        }
    }

    func testSnapshot_tensificationMissed() async {
        let snapshot = await snapshot(for: AnalysisFixtures.tensificationMissed)

        // "학교" → G2P "학꾜" vs hyp "학교": 두 번째 음절 초성만 다름.
        // 빨강 텍스트는 정확히 "교" 한 글자여야 한다.
        XCTAssertEqual(snapshot.sentences.count, 1)
        XCTAssertEqual(snapshot.sentences[0].errorTexts, ["교"])
        XCTAssertTrue(snapshot.sentences[0].topCategories.contains("초성 경음화"),
            "초성 경음화 카테고리가 누락됨")
    }

    func testSnapshot_interWordLinkingCorrect() async {
        let snapshot = await snapshot(for: AnalysisFixtures.interWordLinkingCorrect)

        // 사용자가 G2P 표준대로 어절 사이 연음 적용 → 오류 없음.
        XCTAssertEqual(snapshot.sentences.count, 1)
        XCTAssertFalse(snapshot.sentences[0].hasErrorDetail,
            "정상 발음인데 errorDetail 이 생성됨 — G2P 어절 사이 연음 회귀 의심")
        XCTAssertEqual(snapshot.sentences[0].errorTexts, [])
    }

    func testSnapshot_firstSyllableDropped() async {
        let snapshot = await snapshot(for: AnalysisFixtures.firstSyllableDropped)

        // 첫 음절 누락 → hyp 에 색칠 자리 없음, 그러나 popup 안내용 errorDetail 생성.
        XCTAssertEqual(snapshot.sentences.count, 1)
        XCTAssertTrue(snapshot.sentences[0].hasErrorDetail,
            "누락 음절이 있는데 errorDetail 이 없음 — popup 안내 누락 회귀")
        XCTAssertEqual(snapshot.sentences[0].errorTexts, [],
            "누락된 음절은 hyp 에 표시할 자리가 없어 errorTexts 가 비어야 함")
    }

    // MARK: - Cross-fixture invariants

    func testAllFixturesProduceMatchingSentenceCount() async {
        // fixture 의 phoneticSegments 개수와 분석 결과 sentences 개수가 일치해야 함.
        // (segment 매핑 회귀 감지)
        for fixture in AnalysisFixtures.all {
            let result = await runAnalysis(fixture: fixture)
            XCTAssertEqual(
                result.sentences.count,
                fixture.phoneticSegments.count,
                "fixture '\(fixture.name)' 의 sentence 개수가 phoneticSegments 와 불일치"
            )
        }
    }

    // MARK: - Helpers

    private func snapshot(for fixture: AnalysisFixture) async -> AnalysisSnapshot {
        let result = await runAnalysis(fixture: fixture)
        return AnalysisSnapshot.capture(from: result)
    }

    private func runAnalysis(fixture: AnalysisFixture) async -> PronunciationErrorScript {
        let input = PronunciationErrorScript.makePlainScript(from: fixture.phoneticSegments)
        return await service.analyze(
            phoneticScript: input,
            intentText: fixture.intentText
        )
    }

    /// 새 fixture 작성 시 baseline 값을 캡처하기 위한 디버그 헬퍼.
    /// 실제 assertion 없이 콘솔 로그로 snapshot 을 출력한다. CI 에선 사용하지 않는다.
    @discardableResult
    private func printSnapshot(_ fixture: AnalysisFixture) async -> AnalysisSnapshot {
        let snap = await snapshot(for: fixture)
        print("=== snapshot[\(fixture.name)] ===")
        for (i, s) in snap.sentences.enumerated() {
            print("  sentence[\(i)] errorDetail=\(s.hasErrorDetail)")
            print("    errorTexts=\(s.errorTexts)")
            print("    topCategories=\(s.topCategories)")
        }
        return snap
    }
}
