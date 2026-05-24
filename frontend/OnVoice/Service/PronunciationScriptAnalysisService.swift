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

        // 4) segment 별 cell 그룹화. expected-only(gap) cell 은 인접 segment 에 부착.
        var groups: [Int: [AlignmentCell]] = [:]
        var lastSegment = 0
        for cell in cells {
            if let actualIdx = cell.actualIndex {
                let segIdx = syllableToSegment[actualIdx]
                groups[segIdx, default: []].append(cell)
                lastSegment = segIdx
            } else {
                groups[lastSegment, default: []].append(cell)
            }
        }

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
        var refIndicesInSegment: [Int] = []

        for cell in cells {
            if let ei = cell.expectedIndex { refIndicesInSegment.append(ei) }
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
            }
        }

        let mainSegments = renderSyllableSegments(
            chars: actualChars,
            syllableHasError: syllableHasError
        )

        let hasAnyError = syllableHasError.contains(true)
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
