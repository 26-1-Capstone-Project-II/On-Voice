//
//  PronunciationScript.swift
//  OnVoice
//
//  발음 스크립트(소리나는 대로 전사) 화면이 사용하는 도메인 모델.
//  PronunciationErrorScriptView가 더미 데이터로 들고 있던 타입을
//  외부에서 주입 가능하도록 끌어올린 것이다.
//

import SwiftUI

enum PronunciationSegmentStatus: Equatable {
    case normal
    case muted
    case error
    case success
    case emphasis
}

struct PronunciationTextSegment: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let status: PronunciationSegmentStatus

    var color: Color {
        switch status {
        case .normal: return Color.sub
        case .muted: return Color.gray6
        case .error: return Color(hex: "#FF3867")
        case .success: return Color.main
        case .emphasis: return Color.main
        }
    }

    static func normal(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .normal)
    }

    static func muted(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .muted)
    }

    static func error(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .error)
    }

    static func success(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .success)
    }

    static func emphasis(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, status: .emphasis)
    }
}

struct PronunciationErrorType: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let isDifficult: Bool
    let accentColor: Color

    init(title: String, isDifficult: Bool, accentColor: Color = Color(hex: "#FFA0A0")) {
        self.title = title
        self.isDifficult = isDifficult
        self.accentColor = accentColor
    }
}

struct PronunciationPracticeAttempt: Identifiable, Equatable {
    let id = UUID()
    let segments: [PronunciationTextSegment]
}

struct PronunciationErrorSentence: Identifiable, Equatable {
    let id = UUID()
    let originalSegments: [PronunciationTextSegment]
    let correctSegments: [PronunciationTextSegment]
    let userAttemptSegments: [PronunciationTextSegment]
    let errorTypes: [PronunciationErrorType]
    let dummyAttempts: [PronunciationPracticeAttempt]
}

struct PronunciationTranscriptSentence: Identifiable, Equatable {
    let id = UUID()
    let segments: [PronunciationTextSegment]
    let errorDetail: PronunciationErrorSentence?

    init(
        segments: [PronunciationTextSegment],
        errorDetail: PronunciationErrorSentence? = nil
    ) {
        self.segments = segments
        self.errorDetail = errorDetail
    }
}

struct PronunciationErrorScript: Equatable {
    let sentences: [PronunciationTranscriptSentence]

    static let empty = PronunciationErrorScript(sentences: [])

    var isEmpty: Bool { sentences.isEmpty }
}

extension PronunciationErrorScript {
    /// Whisper segment 배열을 종결 부호(.?!) 기준으로 문장 단위로 쪼개
    /// 한 문장 = 한 PronunciationTranscriptSentence 로 매핑한다.
    /// 한 Whisper segment 안에 여러 문장이 들어와도 각각 분리되어 화면에서
    /// 문장별로 구별·선택할 수 있게 된다(피그마 5-2, 이슈 #106).
    /// errorDetail 은 분석 단계에서 채워지므로 이 함수는 normal segment만 만든다.
    ///
    /// 분석 파이프라인(`PronunciationScriptAnalysisService`)은 sentence 개수와
    /// 무관하게 cell 을 segment 별로 그룹화하므로, 문장 분할이 더 세분화될수록
    /// errorDetail 도 문장 단위로 더 정밀해진다.
    static func makePlainScript(from segments: [String]) -> PronunciationErrorScript {
        let sentences = segments
            .flatMap { splitIntoSentences($0) }
            .map { PronunciationTranscriptSentence(segments: [.normal($0 + " ")]) }

        return sentences.isEmpty ? .empty : PronunciationErrorScript(sentences: sentences)
    }

    /// 종결 부호(.?!) 기준으로 문장을 분할한다. 반환 문자열은 trim 된 상태이며
    /// 종결 부호는 앞 문장에 포함된다(연결 시 호출자가 공백을 덧붙인다).
    ///
    /// 예외 처리:
    ///  - 소수점: 마침표 양옆이 숫자면(예: 5.5) 종결로 보지 않는다.
    ///  - 연속 종결 부호: "...", "?!" 등은 하나의 경계로 묶어 빈/부호만 있는
    ///    조각이 생기지 않게 한다.
    static func splitIntoSentences(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let terminators: Set<Character> = [".", "?", "!"]
        let chars = Array(trimmed)
        var sentences: [String] = []
        var current = ""
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            current.append(ch)

            guard terminators.contains(ch) else {
                i += 1
                continue
            }

            // 소수점(숫자.숫자)은 문장 경계가 아니다.
            if ch == ".", isBetweenDigits(chars, at: i) {
                i += 1
                continue
            }

            // 연속 종결 부호("...", "?!")는 한 경계로 흡수한다.
            var j = i + 1
            while j < chars.count, terminators.contains(chars[j]) {
                current.append(chars[j])
                j += 1
            }

            let chunk = current.trimmingCharacters(in: .whitespaces)
            if !chunk.isEmpty { sentences.append(chunk) }
            current = ""
            i = j
        }

        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { sentences.append(tail) }

        return sentences
    }

    /// chars[index] 의 양옆이 모두 숫자인지(소수점 판정용).
    private static func isBetweenDigits(_ chars: [Character], at index: Int) -> Bool {
        guard index > 0, index + 1 < chars.count else { return false }
        return chars[index - 1].isNumber && chars[index + 1].isNumber
    }
}
