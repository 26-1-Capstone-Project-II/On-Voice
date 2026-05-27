//
//  PronunciationScriptAnalysisService.swift
//  OnVoice
//
//  Apple ASR 의 표기 텍스트(intentText)와 Whisper phonetic 전사 결과를 받아
//  자모 정렬로 오류 음절을 검출하고, PronunciationErrorScript 에 errorDetail 을
//  채워 돌려준다. 파이프라인은 SpeechAnalysisService 헤더 참고.
//
//  설계 메모:
//   - 정렬은 한글 음절만 골라 NW 로 수행한다. 띄어쓰기/구두점이 한쪽에만 있어도
//     비용이 발생하지 않게 해, 자연 발화의 어절 사이 연음이 오답으로 잡히지 않게 한다.
//   - 색칠은 음절 단위. 어절 단위로 통째로 칠하면 어절 안에 정확히 발음한 음절도
//     함께 빨강이 되어 사용자가 어떤 글자를 틀렸는지 모호해진다.
//

import Foundation
import SwiftUI

protocol PronunciationScriptAnalyzing {
    func analyze(
        phoneticScript: PronunciationErrorScript,
        intentText: String?
    ) async -> PronunciationErrorScript
}

final class PronunciationScriptAnalysisService: PronunciationScriptAnalyzing {
    func analyze(
        phoneticScript: PronunciationErrorScript,
        intentText: String?
    ) async -> PronunciationErrorScript {
        guard !phoneticScript.sentences.isEmpty else { return phoneticScript }
        guard let intentText, !intentText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return phoneticScript
        }

        // 1) Apple text → G2P → expected 음절 시퀀스
        let g2p = KoreanG2P.apply(intentText)
        let expectedAll = g2p.phonetic

        // 2) Whisper segments → actual syllable, segment 매핑 트래킹
        var actualAll: [HangulJamo.Syllable] = []
        var syllableToSegment: [Int] = []
        var segmentStartIndices: [Int] = []
        for (segmentIndex, sentence) in phoneticScript.sentences.enumerated() {
            let joined = sentence.segments.map(\.text).joined()
            segmentStartIndices.append(actualAll.count)
            for syl in HangulJamo.decompose(joined) {
                actualAll.append(syl)
                syllableToSegment.append(segmentIndex)
            }
        }

        // 3) 한글만 추출해 자모 정렬, 결과 cell 을 원본 인덱스로 remap.
        let cells = alignHangulOnly(expected: expectedAll, actual: actualAll)

        // 4) segment 별 cell 그룹화.
        //    expected-only gap cell 은 직전/직후 actual cell 의 expectedIndex 거리를
        //    비교해 더 가까운 쪽 segment 에 부착한다 (ref-distance 정책).
        //    이전의 "lastSegment 에 무조건 부착" 정책은 연속 gap 이 segment 경계에
        //    걸칠 때 모두 한쪽 segment 에 몰리는 문제가 있었다. 거리 기반 분배가
        //    누락 음절을 두 segment 사이에 자연스럽게 나눈다.
        let groups = groupCellsBySegment(cells: cells, syllableToSegment: syllableToSegment)

        // 5) 각 Whisper segment → PronunciationTranscriptSentence 재구성
        let sentences = phoneticScript.sentences.enumerated().map {
            (idx, sentence) -> PronunciationTranscriptSentence in
            let segmentText = sentence.segments.map(\.text).joined()
            let cellsInSegment = groups[idx] ?? []
            let segmentOffset = segmentStartIndices[idx]
            return Self.buildSentence(
                segmentText: segmentText,
                cells: cellsInSegment,
                segmentOffset: segmentOffset,
                g2p: g2p,
                expectedAll: expectedAll
            )
        }

        return PronunciationErrorScript(sentences: sentences)
    }

    // MARK: - Segment grouping (ref-distance based)

    /// cells 를 segment 별로 그룹화한다.
    ///  - actual cell 은 syllableToSegment[actualIndex] 에 그대로 부착.
    ///  - expected-only gap cell 은 cells 시퀀스에서 직전/직후 actual cell 의
    ///    expectedIndex 와의 거리를 비교해 더 가까운 쪽 segment 에 부착.
    ///  - cells 양 끝의 gap 은 한쪽만 actual 이 있으면 그쪽에 부착.
    ///  - actual cell 이 한 번도 없으면 (=hyp 가 비어있는 비정상 케이스) 모두 무시.
    ///
    /// `internal` 로 노출되어 단위 테스트에서 직접 호출 가능 (어떤 cell 이 어느 segment 로
    /// 가는지 직접 검증). 외부 호출자는 analyze() 만 사용한다.
    func groupCellsBySegment(
        cells: [AlignmentCell],
        syllableToSegment: [Int]
    ) -> [Int: [AlignmentCell]] {
        // 각 cell 에 대한 segment 결정값. nil 이면 부착하지 않음.
        var resolved: [Int?] = Array(repeating: nil, count: cells.count)

        // actual cell 은 즉시 결정 가능.
        for (i, cell) in cells.enumerated() {
            if let actualIdx = cell.actualIndex {
                resolved[i] = syllableToSegment[actualIdx]
            }
        }

        // expected-only gap 은 양 옆 actual cell 의 expectedIndex 거리로 분배.
        for i in 0..<cells.count where resolved[i] == nil {
            let cell = cells[i]
            guard let gapExpected = cell.expectedIndex else { continue }

            let prev = nearestNeighborWithExpectedIndex(
                in: cells,
                from: i,
                stride: -1,
                resolved: resolved
            )
            let next = nearestNeighborWithExpectedIndex(
                in: cells,
                from: i,
                stride: +1,
                resolved: resolved
            )

            resolved[i] = pickSegment(
                gapExpected: gapExpected,
                prev: prev,
                next: next
            )
        }

        var groups: [Int: [AlignmentCell]] = [:]
        for (i, segOpt) in resolved.enumerated() {
            guard let seg = segOpt else { continue }
            groups[seg, default: []].append(cells[i])
        }
        return groups
    }

    /// 한 방향으로 스캔해 (actualIndex != nil AND expectedIndex != nil AND resolved 된)
    /// 가장 가까운 cell 의 (expectedIndex, segment) 쌍을 돌려준다.
    private func nearestNeighborWithExpectedIndex(
        in cells: [AlignmentCell],
        from index: Int,
        stride step: Int,
        resolved: [Int?]
    ) -> (expectedIndex: Int, segment: Int)? {
        var j = index + step
        while j >= 0 && j < cells.count {
            if cells[j].actualIndex != nil,
               let exp = cells[j].expectedIndex,
               let seg = resolved[j] {
                return (exp, seg)
            }
            j += step
        }
        return nil
    }

    /// gap 의 expectedIndex 와 prev/next 의 (expectedIndex, segment) 를 보고 분배.
    /// 한쪽만 있으면 그쪽으로, 둘 다 있으면 거리 비교(동률은 prev 선호).
    /// 둘 다 nil 이면 nil (=어디에도 부착 안 함).
    private func pickSegment(
        gapExpected: Int,
        prev: (expectedIndex: Int, segment: Int)?,
        next: (expectedIndex: Int, segment: Int)?
    ) -> Int? {
        switch (prev, next) {
        case let (.some(p), .some(n)):
            let distPrev = abs(gapExpected - p.expectedIndex)
            let distNext = abs(n.expectedIndex - gapExpected)
            return distPrev <= distNext ? p.segment : n.segment
        case let (.some(p), nil):
            return p.segment
        case let (nil, .some(n)):
            return n.segment
        case (nil, nil):
            return nil
        }
    }

    // MARK: - Hangul-only alignment with index remapping

    private func alignHangulOnly(
        expected: [HangulJamo.Syllable],
        actual: [HangulJamo.Syllable]
    ) -> [AlignmentCell] {
        let expectedHangulOriginalIdx = expected.enumerated()
            .filter { $0.element.isHangul }
            .map(\.offset)
        let actualHangulOriginalIdx = actual.enumerated()
            .filter { $0.element.isHangul }
            .map(\.offset)

        let expectedHangul = expectedHangulOriginalIdx.map { expected[$0] }
        let actualHangul = actualHangulOriginalIdx.map { actual[$0] }

        let rawCells = JamoAligner.align(expected: expectedHangul, actual: actualHangul)

        return rawCells.map { cell in
            AlignmentCell(
                expected: cell.expected,
                actual: cell.actual,
                expectedIndex: cell.expectedIndex.map { expectedHangulOriginalIdx[$0] },
                actualIndex: cell.actualIndex.map { actualHangulOriginalIdx[$0] },
                differences: cell.differences
            )
        }
    }

    // MARK: - Sentence builder

    private static func buildSentence(
        segmentText: String,
        cells: [AlignmentCell],
        segmentOffset: Int,
        g2p: G2PResult,
        expectedAll: [HangulJamo.Syllable]
    ) -> PronunciationTranscriptSentence {
        let actualChars = Array(segmentText)

        // 음절 단위 오류 표시: actual char 인덱스마다 boolean
        var syllableHasError = Array(repeating: false, count: actualChars.count)
        var categories: [PronunciationErrorCategory] = []
        // popup 의 ref/correct 텍스트 범위 산정용. actualIndex 가 있는(=이 segment 에
        // 확실히 속하는) cell 의 expectedIndex 만 채택한다. expected-only gap cell 은
        // lastSegment 부착 정책으로 segment 경계를 넘는 expectedIndex 를 가져올
        // 수 있어 popup 범위가 잘못 잡힐 수 있으므로 제외한다.
        var refIndicesInSegment: [Int] = []
        // 사용자가 발음하지 않고 빠뜨린(=expected-only gap) 한글 음절이 있는지.
        // 색칠 자리는 없지만 popup 에 정답 발음을 보여주기 위해 errorDetail 은 만들어야 한다.
        var hasDroppedExpected = false

        for cell in cells {
            if cell.actualIndex != nil, let ei = cell.expectedIndex {
                refIndicesInSegment.append(ei)
            }
            guard cell.hasError else { continue }

            // 비-한글 cell(공백/구두점 차이) 은 분류/색칠 대상에서 제외.
            let isHangulCell =
                (cell.expected?.isHangul ?? false) || (cell.actual?.isHangul ?? false)
            guard isHangulCell else { continue }

            let next = cell.expectedIndex.flatMap { idx in
                idx + 1 < expectedAll.count ? expectedAll[idx + 1] : nil
            }
            categories.append(contentsOf:
                PronunciationErrorClassifier.classify(cell: cell, nextExpected: next)
            )

            if let actualIdx = cell.actualIndex {
                let localIdx = actualIdx - segmentOffset
                if (0..<actualChars.count).contains(localIdx) {
                    // 비-한글 char(공백) 은 색칠 안 함
                    let ch = actualChars[localIdx]
                    if HangulJamo.decompose(ch).isHangul {
                        syllableHasError[localIdx] = true
                    }
                }
            } else if cell.expected?.isHangul == true {
                // hyp 자리가 없는 누락된 한글 음절. expectedIndex 도 popup 범위에 포함.
                if let ei = cell.expectedIndex { refIndicesInSegment.append(ei) }
                hasDroppedExpected = true
            }
        }

        let mainSegments = renderSyllableSegments(
            chars: actualChars,
            syllableHasError: syllableHasError
        )

        // errorDetail 생성 트리거는 두 가지:
        //   1) hyp 측에 색칠할 음절이 있음 (사용자가 다르게 발음)
        //   2) ref 에 있지만 hyp 에 없는 한글 음절이 있음 (사용자가 누락)
        // 둘 중 하나라도 있으면 popup 을 띄울 가치가 있다. 분류 결과는 잡혔는데
        // 색칠 대상이 없다고 errorDetail 을 통째로 버리는 silent 데이터 손실을 막는다.
        let hasAnyError = syllableHasError.contains(true) || hasDroppedExpected
        guard hasAnyError else {
            return PronunciationTranscriptSentence(
                segments: [.normal(segmentText)],
                errorDetail: nil
            )
        }

        // popup: originalSegments(표기, muted), correctSegments(올바른 발음, normal) 는
        // 한 덩어리 단순 표시(가독성 emphasis 색칠은 의도적으로 롤백).
        // userAttemptSegments 만 음절 단위 빨강.
        let (originalText, correctText) = expectedRangeText(
            refIndices: refIndicesInSegment,
            g2p: g2p
        )
        let errorTypes = topErrorTypes(categories)

        let errorDetail = PronunciationErrorSentence(
            originalSegments: [.muted(originalText)],
            correctSegments: [.normal(correctText)],
            userAttemptSegments: mainSegments,
            errorTypes: errorTypes,
            dummyAttempts: []
        )

        return PronunciationTranscriptSentence(segments: mainSegments, errorDetail: errorDetail)
    }

    // MARK: - Renderer

    private static func renderSyllableSegments(
        chars: [Character],
        syllableHasError: [Bool]
    ) -> [PronunciationTextSegment] {
        guard !chars.isEmpty else { return [] }
        var segments: [PronunciationTextSegment] = []
        var buffer = ""
        var currentStatus: PronunciationSegmentStatus = .normal

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(PronunciationTextSegment(text: buffer, status: currentStatus))
            buffer = ""
        }

        for (i, ch) in chars.enumerated() {
            let isError = i < syllableHasError.count && syllableHasError[i]
            let status: PronunciationSegmentStatus = isError ? .error : .normal
            if status != currentStatus {
                flush()
                currentStatus = status
            }
            buffer.append(ch)
        }
        flush()
        return segments
    }

    // MARK: - Expected slice

    /// G2P 는 음절 1:1 변환이라 g2p.original 과 g2p.phonetic 의 길이가 동일하다.
    /// 같은 [lo, hi] 범위로 양쪽을 슬라이스해도 비-한글(공백/구두점) 위치가
    /// 어긋나지 않는다. 안전을 위해 길이 일치를 명시적으로 가드하고, 어긋나면
    /// (회귀로 들어왔을 때) full text 로 fallback 한다.
    private static func expectedRangeText(
        refIndices: [Int],
        g2p: G2PResult
    ) -> (original: String, correct: String) {
        let originalFull = HangulJamo.compose(g2p.original)
        let correctFull = g2p.phoneticText

        guard g2p.original.count == g2p.phonetic.count else {
            assertionFailure("G2P original/phonetic length mismatch — invariant broken")
            return (originalFull, correctFull)
        }
        guard let lo = refIndices.min(),
              let hi = refIndices.max(),
              lo <= hi,
              !g2p.original.isEmpty else {
            return (originalFull, correctFull)
        }
        let cappedLo = max(0, lo)
        let cappedHi = min(g2p.original.count - 1, hi)
        guard cappedLo <= cappedHi else { return (originalFull, correctFull) }
        let originalSlice = Array(g2p.original[cappedLo...cappedHi])
        let correctSlice = Array(g2p.phonetic[cappedLo...cappedHi])
        return (HangulJamo.compose(originalSlice), HangulJamo.compose(correctSlice))
    }

    // MARK: - Error type ranking

    private static func topErrorTypes(
        _ categories: [PronunciationErrorCategory]
    ) -> [PronunciationErrorType] {
        guard !categories.isEmpty else { return [] }
        var counts: [PronunciationErrorCategory: Int] = [:]
        for c in categories { counts[c, default: 0] += 1 }
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.rawValue < rhs.key.rawValue
        }
        return sorted.prefix(3).map { entry in
            PronunciationErrorType(
                title: entry.key.rawValue,
                isDifficult: false,
                accentColor: accentColor(for: entry.key)
            )
        }
    }

    private static func accentColor(for category: PronunciationErrorCategory) -> Color {
        switch category.slot {
        case .initial: return Color(hex: "#FFA0A0")
        case .medial:  return Color(hex: "#B2B8FF")
        case .final:   return Color(hex: "#FFF79E")
        case .none:    return Color(hex: "#FFA0A0")
        }
    }
}
