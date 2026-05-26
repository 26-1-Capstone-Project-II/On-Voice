//
//  JamoAligner.swift
//  OnVoice
//
//  기대 발음(Apple ASR + G2P)과 실제 발음(Whisper) 두 음절 시퀀스를
//  Needleman-Wunsch 로 정렬해 어느 음절의 어느 자모(초/중/종)에서
//  차이가 났는지 cell 단위로 돌려준다.
//

import Foundation

enum JamoSlot: Equatable {
    case initial
    case medial
    case final
}

struct JamoDifference: Equatable {
    let slot: JamoSlot
    let expected: Character?    // nil = 비어있던 자모(예: 종성 없음)
    let actual: Character?
}

/// 정렬 한 칸. expectedSyllable/actualSyllable 중 하나가 nil 이면 그쪽이 gap.
/// expectedIndex/actualIndex 는 원본 시퀀스에서의 위치(없으면 nil).
struct AlignmentCell: Equatable {
    let expected: HangulJamo.Syllable?
    let actual: HangulJamo.Syllable?
    let expectedIndex: Int?
    let actualIndex: Int?
    let differences: [JamoDifference]

    /// gap 이거나 자모 차이가 1개 이상 있으면 true.
    var hasError: Bool {
        expected == nil || actual == nil || !differences.isEmpty
    }
}

enum JamoAligner {
    /// gap(음절 전체 누락/삽입) 비용. 자모 1개 차이가 1 이므로 3 으로 두면
    /// "음절 통째로 빠짐"과 "음절 자모 3개 모두 다름"이 동률이 되어 두 시퀀스 길이가
    /// 비슷할 때 substitution 을 우선시한다.
    private static let gapCost = 3

    static func align(
        expected: [HangulJamo.Syllable],
        actual: [HangulJamo.Syllable]
    ) -> [AlignmentCell] {
        let m = expected.count
        let n = actual.count

        // dp[i][j] = cost to align expected[0..<i] with actual[0..<j]
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i * gapCost }
        for j in 0...n { dp[0][j] = j * gapCost }

        for i in 1...max(m, 1) {
            guard i <= m else { break }
            for j in 1...max(n, 1) {
                guard j <= n else { break }
                let subCost = substitutionCost(expected[i - 1], actual[j - 1])
                let diag = dp[i - 1][j - 1] + subCost
                let up = dp[i - 1][j] + gapCost
                let left = dp[i][j - 1] + gapCost
                dp[i][j] = min(diag, min(up, left))
            }
        }

        // Backtrack tie-break 정책 (비용이 같을 때 어떤 경로를 택할지):
        //   1) substitution (diagonal) 최우선
        //   2) expected-only gap (up) 다음
        //   3) actual-only gap (left) 마지막
        // 이유: 같은 비용이면 두 음절을 정렬해 대응 관계를 만드는 substitution 이
        // 사용자 입장에서 "이 음절이 저 음절에 해당한다" 는 정보를 더 많이 준다.
        // gap 으로 흘려보내면 어느 음절이 빠졌는지만 알 수 있고 대응 음절이 비게 된다.
        // 이 순서는 같은 입력에 대해 결정적 출력을 보장한다.
        var cells: [AlignmentCell] = []
        var i = m
        var j = n
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let subCost = substitutionCost(expected[i - 1], actual[j - 1])
                if dp[i][j] == dp[i - 1][j - 1] + subCost {
                    let diffs = jamoDifferences(expected[i - 1], actual[j - 1])
                    cells.append(AlignmentCell(
                        expected: expected[i - 1],
                        actual: actual[j - 1],
                        expectedIndex: i - 1,
                        actualIndex: j - 1,
                        differences: diffs
                    ))
                    i -= 1; j -= 1
                    continue
                }
            }
            if i > 0, dp[i][j] == dp[i - 1][j] + gapCost {
                cells.append(AlignmentCell(
                    expected: expected[i - 1],
                    actual: nil,
                    expectedIndex: i - 1,
                    actualIndex: nil,
                    differences: []
                ))
                i -= 1
                continue
            }
            // j > 0
            cells.append(AlignmentCell(
                expected: nil,
                actual: actual[j - 1],
                expectedIndex: nil,
                actualIndex: j - 1,
                differences: []
            ))
            j -= 1
        }

        return cells.reversed()
    }

    // MARK: - Cost / diff helpers

    private static func substitutionCost(
        _ expected: HangulJamo.Syllable,
        _ actual: HangulJamo.Syllable
    ) -> Int {
        // 비-한글 vs 비-한글: 같으면 0, 다르면 2(자모 비교가 불가능하므로 중간값).
        if !expected.isHangul || !actual.isHangul {
            return expected.composed == actual.composed ? 0 : 2
        }
        let diffs = jamoDifferences(expected, actual).count
        // 자모 3개가 모두 다르면 두 음절이 사실상 무관계. gapCost(=3) 와 동률이면
        // 알고리즘이 substitution 을 선호해 "음절 통째 누락"이 잘못 분류될 수 있다.
        // +1 페널티로 이 경우엔 gap 경로가 우선되도록 한다.
        return diffs >= 3 ? diffs + 1 : diffs
    }

    private static func jamoDifferences(
        _ expected: HangulJamo.Syllable,
        _ actual: HangulJamo.Syllable
    ) -> [JamoDifference] {
        guard expected.isHangul, actual.isHangul else { return [] }
        var diffs: [JamoDifference] = []
        if expected.initialIndex != actual.initialIndex {
            diffs.append(.init(
                slot: .initial,
                expected: expected.initial,
                actual: actual.initial
            ))
        }
        if expected.medialIndex != actual.medialIndex {
            diffs.append(.init(
                slot: .medial,
                expected: expected.medial,
                actual: actual.medial
            ))
        }
        if expected.finalIndex != actual.finalIndex {
            diffs.append(.init(
                slot: .final,
                expected: expected.final,
                actual: actual.final
            ))
        }
        return diffs
    }
}
