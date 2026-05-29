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
        /// 이번 시도에서 새로 맞춘(=평가 대상에서 빠지는) expected 음절 인덱스.
        /// 호출부가 remaining 집합을 줄여 다음 시도에서 같은 음절을 다시 평가하지 않게 한다.
        let correctedExpectedIndices: Set<Int>
        /// 평가 대상(remaining)이 모두 교정돼 더 평가할 게 없으면 true → 난이도 버튼 노출 트리거.
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
    ///
    /// 평가는 **아직 교정되지 않은 원래 오류 음절(remaining)** 에만 적용한다. 원래 맞았던
    /// 음절이나 이전 시도에서 이미 맞춘 음절은 평가에서 제외해(빨강/성공판정에 영향 없음)
    /// 파인튜닝 모델의 오인식 때문에 전체 성공이 무한정 지연되는 것을 막는다(이슈 #117 후속).
    ///
    /// - newCells: 새 attempt를 referenceText 로 정렬한 결과.
    /// - newHypText: 새 attempt 의 phonetic 전사(단일 세그먼트). actualIndex 는 이 문자열의
    ///   char 인덱스와 1:1 이다(분석 파이프라인의 buildSentence 와 동일 규약).
    /// - originalErrorExpectedIndices: 원본 attempt 에서 틀렸던 expected 음절 인덱스 전체(파랑 표시 기준).
    /// - remainingExpectedIndices: 아직 교정 못한 평가 대상(빨강/성공 판정 기준). 원래 오류의 부분집합.
    static func colorize(
        newCells: [AlignmentCell],
        newHypText: String,
        originalErrorExpectedIndices: Set<Int>,
        remainingExpectedIndices: Set<Int>
    ) -> Outcome {
        let chars = Array(newHypText)
        var status = Array(repeating: PronunciationSegmentStatus.normal, count: chars.count)
        var corrected = Set<Int>()

        for cell in newCells {
            let isHangulCell = (cell.expected?.isHangul ?? false) || (cell.actual?.isHangul ?? false)
            guard isHangulCell, let expectedIndex = cell.expectedIndex else { continue }

            guard let actualIndex = cell.actualIndex,
                  (0..<chars.count).contains(actualIndex),
                  HangulJamo.decompose(chars[actualIndex]).isHangul else {
                // 색칠할 hyp 자리가 없는 누락 음절. 성공 판정은 remaining/corrected 차집합으로 한다.
                continue
            }

            if remainingExpectedIndices.contains(expectedIndex), cell.hasError {
                // 아직 교정 안 된 평가 대상이 여전히 틀림 → 빨강.
                status[actualIndex] = .error
            } else if originalErrorExpectedIndices.contains(expectedIndex), !cell.hasError {
                // 원래 틀렸던 음절을 맞춤 → 파랑(이미 교정해 잠긴 음절도 다시 보이면 파랑 유지).
                status[actualIndex] = .success
                if remainingExpectedIndices.contains(expectedIndex) {
                    corrected.insert(expectedIndex)
                }
            }
            // 그 외(원래도 맞았던 음절 등)는 평가 제외 → 일반색(틀려도 빨강 아님).
        }

        return Outcome(
            segments: renderSegments(chars: chars, status: status),
            correctedExpectedIndices: corrected,
            isFullSuccess: remainingExpectedIndices.subtracting(corrected).isEmpty
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
