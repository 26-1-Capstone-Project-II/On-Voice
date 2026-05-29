//
//  RepracticeColorizer.swift
//  OnVoice
//
//  오류 문장 재연습(이슈 #117)의 색상 diff 로직.
//  원본 attempt와 새 attempt를 같은 referenceText 좌표계로 각각 자모 정렬한 결과
//  (AlignmentCell 배열)를 받아, 새 attempt의 음절을 세 갈래로 색칠한다:
//   - 빨강(.error)   : 이번에도 여전히 틀린 음절
//   - 파랑(.success) : 원래는 틀렸지만 이번에 맞춘 음절
//   - 일반(.normal)  : 원래도 맞았고 이번에도 맞은 음절
//  또한 빨강·누락 음절이 하나도 없으면 "문장 전체 성공" 으로 본다.
//
//  순수 함수만 노출해 단위 테스트가 정렬 결과를 직접 구성해 검증할 수 있게 한다.
//

import Foundation

enum RepracticeColorizer {
    struct Outcome: Equatable {
        let segments: [PronunciationTextSegment]
        /// 빨강(틀림)·누락 음절이 하나도 없으면 true → 난이도 버튼 노출 트리거.
        let isFullSuccess: Bool
    }

    /// 정렬 결과에서 "사용자가 틀린(또는 누락한) 한글 expected 음절" 의 인덱스 집합.
    /// substitution(자모 차이) 과 deletion(누락, actual=nil) 모두 hasError 이며
    /// expectedIndex/expected 가 있으므로 한 번에 잡힌다.
    static func errorExpectedIndices(cells: [AlignmentCell]) -> Set<Int> {
        var indices = Set<Int>()
        for cell in cells where cell.hasError {
            guard cell.expected?.isHangul == true, let expectedIndex = cell.expectedIndex else { continue }
            indices.insert(expectedIndex)
        }
        return indices
    }

    /// 새 attempt 의 hyp 텍스트를 음절 단위로 색칠한다.
    /// - newCells: 새 attempt를 referenceText 로 정렬한 결과.
    /// - newHypText: 새 attempt 의 phonetic 전사(단일 세그먼트). actualIndex 는 이 문자열의
    ///   char 인덱스와 1:1 이다(분석 파이프라인의 buildSentence 와 동일 규약).
    /// - originalErrorExpectedIndices: 원본 attempt 에서 틀렸던 expected 음절 인덱스 집합.
    static func colorize(
        newCells: [AlignmentCell],
        newHypText: String,
        originalErrorExpectedIndices: Set<Int>
    ) -> Outcome {
        let chars = Array(newHypText)
        var status = Array(repeating: PronunciationSegmentStatus.normal, count: chars.count)
        var hasRedOrDropped = false

        for cell in newCells {
            let isHangulCell = (cell.expected?.isHangul ?? false) || (cell.actual?.isHangul ?? false)
            guard isHangulCell else { continue }

            if let actualIndex = cell.actualIndex,
               (0..<chars.count).contains(actualIndex),
               HangulJamo.decompose(chars[actualIndex]).isHangul {
                if cell.hasError {
                    status[actualIndex] = .error
                    hasRedOrDropped = true
                } else if let expectedIndex = cell.expectedIndex,
                          originalErrorExpectedIndices.contains(expectedIndex) {
                    status[actualIndex] = .success
                }
            } else if cell.expected?.isHangul == true, cell.actualIndex == nil {
                // hyp 에 색칠할 자리가 없는 누락 음절. 성공 판정에서만 제외 신호로 쓴다.
                hasRedOrDropped = true
            }
        }

        return Outcome(
            segments: renderSegments(chars: chars, status: status),
            isFullSuccess: !hasRedOrDropped
        )
    }

    /// 연속된 동일 status 를 한 segment 로 병합한다(분석 파이프라인 renderSyllableSegments 와 동일).
    private static func renderSegments(
        chars: [Character],
        status: [PronunciationSegmentStatus]
    ) -> [PronunciationTextSegment] {
        guard !chars.isEmpty else { return [] }
        var segments: [PronunciationTextSegment] = []
        var buffer = ""
        var currentStatus = status.first ?? .normal

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(PronunciationTextSegment(text: buffer, status: currentStatus))
            buffer = ""
        }

        for (i, ch) in chars.enumerated() {
            let s = i < status.count ? status[i] : .normal
            if s != currentStatus {
                flush()
                currentStatus = s
            }
            buffer.append(ch)
        }
        flush()
        return segments
    }
}
