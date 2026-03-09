//
//  SpeechAnalysisService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

struct SpeechAnalysisResult {
    let appleTranscript: String
    let standardText: String
    let standardPronunciation: String
    let sentences: [SentenceComparison]
    let overallAccuracy: Double

    var errorSentences: [SentenceComparison] {
        sentences.filter { $0.accuracy < 0.8 }
    }
}

final class SpeechAnalysisService {
    private let transcriptionService: AppleSpeechTranscriptionService

    init(transcriptionService: AppleSpeechTranscriptionService = AppleSpeechTranscriptionService()) {
        self.transcriptionService = transcriptionService
    }

    func analyze(url: URL, referenceText: String? = nil) async -> SpeechAnalysisResult {
        await transcriptionService.requestAuthorizationIfNeeded()

        let (userText, _) = await transcriptionService.transcribe(url: url)
        let standardText = generateStandardText(from: referenceText ?? userText)
        let standardPronunciation = generateStandardPronunciation(from: standardText)
        let userPronunciation = convertToPhoneticText(userText)
        let sentences = compareSentences(
            standardText: standardText,
            standardPronunciation: standardPronunciation,
            userPronunciation: userPronunciation
        )
        let correctCount = sentences.filter { $0.isCorrect }.count
        let overallAccuracy = sentences.isEmpty ? 0 : Double(correctCount) / Double(sentences.count)

        let result = SpeechAnalysisResult(
            appleTranscript: userText,
            standardText: standardText,
            standardPronunciation: standardPronunciation,
            sentences: sentences,
            overallAccuracy: overallAccuracy
        )

        log(result: result, userPronunciation: userPronunciation)
        return result
    }

    private func log(result: SpeechAnalysisResult, userPronunciation: String) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎤 [STT 변환 결과 분석]")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 원본 STT 결과: \(result.appleTranscript)")
        print("📝 표준문장: \(result.standardText)")
        print("🗣️ 표준발음: \(result.standardPronunciation)")
        print("👤 나의발음: \(userPronunciation)")
        print("📊 전체 정확도: \(String(format: "%.1f", result.overallAccuracy * 100))%")
        print("❌ 발음 오류 문장 수: \(result.errorSentences.count)개")

        for (index, sentence) in result.sentences.enumerated() {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📄 문장 \(index + 1)")
            print("📝 표준문장: \(sentence.reference)")
            print("🗣️ 표준발음: \(sentence.standardPronunciation)")
            print("👤 나의발음: \(sentence.hypothesis)")
            print("📊 정확도: \(String(format: "%.1f", sentence.accuracy * 100))%")
            print("✅ 정확 여부: \(sentence.isCorrect ? "정확" : "오류")")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func generateStandardText(from text: String) -> String {
        var corrected = text

        corrected = corrected.replacingOccurrences(of: "됬", with: "됐")
        corrected = corrected.replacingOccurrences(of: "되여", with: "되어")
        corrected = corrected.replacingOccurrences(of: "하구", with: "하고")
        corrected = corrected.replacingOccurrences(of: "머구", with: "먹고")
        corrected = corrected.replacingOccurrences(of: "갔구", with: "갔고")
        corrected = corrected.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        corrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)

        return corrected
    }

    private func generateStandardPronunciation(from text: String) -> String {
        let doubleFinalMap: [Int: (Int, Int)] = [
            3: (1, 19),
            5: (4, 22),
            6: (4, 27),
            9: (8, 1),
            10: (8, 16),
            11: (8, 17),
            12: (8, 19),
            13: (8, 25),
            14: (8, 26),
            15: (8, 27),
            18: (17, 19)
        ]
        let finalToInitial: [Int: Int] = [
            1: 0, 2: 1, 4: 2, 7: 3, 8: 5,
            16: 6, 17: 7, 19: 9, 20: 10, 21: 11,
            22: 12, 23: 14, 24: 15, 25: 16, 26: 17,
            27: 18
        ]

        struct Syllable {
            var initial: Int
            var medial: Int
            var final: Int
            var isHangul: Bool
            var char: Character
        }

        var syllables: [Syllable] = []
        for ch in text {
            if let scalar = ch.unicodeScalars.first, scalar.value >= 0xAC00 && scalar.value <= 0xD7A3 {
                let code = Int(scalar.value) - 0xAC00
                let finalIndex = code % 28
                let medialIndex = (code / 28) % 21
                let initialIndex = code / (28 * 21)
                syllables.append(
                    Syllable(
                        initial: initialIndex,
                        medial: medialIndex,
                        final: finalIndex,
                        isHangul: true,
                        char: ch
                    )
                )
            } else {
                syllables.append(Syllable(initial: 0, medial: 0, final: 0, isHangul: false, char: ch))
            }
        }

        if syllables.count > 1 {
            for i in 0..<(syllables.count - 1) {
                guard syllables[i].isHangul else { continue }

                var j = i + 1
                while j < syllables.count && !syllables[j].isHangul { j += 1 }
                guard j < syllables.count, syllables[j].isHangul else { continue }

                if syllables[i].final != 0 && syllables[j].initial == 11 {
                    let fin = syllables[i].final
                    if fin == 27 {
                        syllables[i].final = 0
                    } else if let (firstFin, secondFin) = doubleFinalMap[fin] {
                        if secondFin == 27 {
                            syllables[i].final = 0
                            if let newInit = finalToInitial[firstFin] {
                                syllables[j].initial = newInit
                            }
                        } else {
                            syllables[i].final = firstFin
                            if let newInit = finalToInitial[secondFin] {
                                syllables[j].initial = newInit
                            }
                        }
                    } else if (fin == 7 || fin == 25) && syllables[j].medial == 20 {
                        syllables[i].final = 0
                        syllables[j].initial = (fin == 7 ? 12 : 14)
                    } else {
                        if let newInit = finalToInitial[fin] {
                            syllables[j].initial = newInit
                        }
                        syllables[i].final = 0
                    }
                }
            }
        }

        if syllables.count > 1 {
            for i in 0..<(syllables.count - 1) {
                guard syllables[i].isHangul else { continue }

                var j = i + 1
                while j < syllables.count && !syllables[j].isHangul { j += 1 }
                guard j < syllables.count, syllables[j].isHangul else { continue }

                let fin = syllables[i].final
                let initNext = syllables[j].initial

                if fin == 27 && [0, 3, 7, 12].contains(initNext) {
                    let aspiratedMap: [Int: Int] = [0: 15, 3: 16, 7: 17, 12: 14]
                    if let newInit = aspiratedMap[initNext] {
                        syllables[j].initial = newInit
                    }
                    syllables[i].final = 0
                } else if fin == 6 && [0, 3, 7, 12].contains(initNext) {
                    let aspiratedMap: [Int: Int] = [0: 15, 3: 16, 7: 17, 12: 14]
                    if let newInit = aspiratedMap[initNext] {
                        syllables[j].initial = newInit
                    }
                    syllables[i].final = 4
                } else if fin == 15 && [0, 3, 7, 12].contains(initNext) {
                    let aspiratedMap: [Int: Int] = [0: 15, 3: 16, 7: 17, 12: 14]
                    if let newInit = aspiratedMap[initNext] {
                        syllables[j].initial = newInit
                    }
                    syllables[i].final = 8
                }

                if initNext == 18 && ![0, 4, 8, 16, 21, 27].contains(fin) {
                    var baseFin = fin
                    if let (firstFin, _) = doubleFinalMap[fin] {
                        switch fin {
                        case 11, 14:
                            baseFin = 17
                        case 12, 13:
                            baseFin = 8
                        case 3, 9:
                            baseFin = 1
                        case 18:
                            baseFin = 17
                        default:
                            baseFin = firstFin
                        }
                    }

                    if [1, 2, 24].contains(baseFin) {
                        syllables[j].initial = 15
                    } else if [7, 25, 19, 20, 22, 23].contains(baseFin) {
                        syllables[j].initial = 16
                    } else if [17, 26].contains(baseFin) {
                        syllables[j].initial = 17
                    }
                    syllables[i].final = 0
                }

                if [2, 6].contains(initNext) {
                    if [1, 2, 24].contains(fin) {
                        syllables[i].final = 21
                    } else if [7, 25, 19, 20, 22, 23].contains(fin) {
                        syllables[i].final = 4
                    } else if [17, 26].contains(fin) {
                        syllables[i].final = 16
                    } else if fin == 3 {
                        syllables[i].final = 21
                    } else if fin == 18 {
                        syllables[i].final = 16
                    }

                    if fin == 6 {
                        syllables[i].final = 4
                    } else if fin == 15 {
                        syllables[i].final = 8
                    }
                }

                if fin == 4 && initNext == 5 {
                    syllables[i].final = 8
                }
                if fin == 8 && initNext == 2 {
                    syllables[j].initial = 5
                }
                if [4, 16, 21].contains(fin) && initNext == 5 {
                    syllables[j].initial = 2
                }

                if [0, 3, 7, 9, 12].contains(initNext) && ![0, 4, 6, 8, 15, 16, 21, 27].contains(fin) {
                    let tenseMap: [Int: Int] = [0: 1, 3: 4, 7: 8, 9: 10, 12: 13]
                    if let newInit = tenseMap[initNext] {
                        syllables[j].initial = newInit
                    }
                }
                if initNext == 15 && ![0, 4, 6, 8, 15, 16, 21, 27].contains(fin) {
                    syllables[j].initial = 1
                }
                if initNext == 17 && ![0, 4, 6, 8, 15, 16, 21, 27].contains(fin) {
                    syllables[j].initial = 8
                }
            }
        }

        var result = ""
        for syllable in syllables {
            if syllable.isHangul {
                let unicodeValue = syllable.initial * 21 * 28 + syllable.medial * 28 + syllable.final + 0xAC00
                if let scalar = UnicodeScalar(unicodeValue) {
                    result.append(Character(scalar))
                }
            } else {
                result.append(syllable.char)
            }
        }
        return result
    }

    private func convertToPhoneticText(_ text: String) -> String {
        text
    }

    private func compareSentences(
        standardText: String,
        standardPronunciation: String,
        userPronunciation: String
    ) -> [SentenceComparison] {
        let standardSentences = sentenceSplit(standardText)
        let standardPronSentences = sentenceSplit(standardPronunciation)
        let userPronSentences = sentenceSplit(userPronunciation)

        let count = max(standardSentences.count, max(standardPronSentences.count, userPronSentences.count))
        var results: [SentenceComparison] = []

        for i in 0..<count {
            let standardSent = i < standardSentences.count ? standardSentences[i] : ""
            let standardPron = i < standardPronSentences.count ? standardPronSentences[i] : ""
            let userPron = i < userPronSentences.count ? userPronSentences[i] : ""

            let standardTokens = tokenize(standardPron)
            let userTokens = tokenize(userPron)

            let (distance, backtrace) = editDistanceWithPath(standardTokens, userTokens)
            let wer = standardTokens.isEmpty ? 0 : Double(distance) / Double(max(1, standardTokens.count))
            let accuracy = max(0.0, 1.0 - wer)

            let (refPieces, hypPieces) = buildPieces(standardTokens, userTokens, backtrace: backtrace)

            results.append(
                SentenceComparison(
                    index: i + 1,
                    reference: standardSent,
                    standardPronunciation: standardPron,
                    hypothesis: userPron,
                    referencePieces: refPieces,
                    hypothesisPieces: hypPieces,
                    accuracy: accuracy,
                    isCorrect: accuracy >= 0.8
                )
            )
        }

        return results.filter { !$0.reference.isEmpty }
    }

    private func sentenceSplit(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".?!。？！"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func tokenize(_ sentence: String) -> [String] {
        let trimmed = sentence.lowercased()
        return trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    private enum Step {
        case match
        case sub
        case ins
        case del
    }

    private func editDistanceWithPath(_ ref: [String], _ hyp: [String]) -> (Int, [Step]) {
        let m = ref.count
        let n = hyp.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        var bt = Array(repeating: Array(repeating: Step.match, count: n + 1), count: m + 1)

        for i in 0...m {
            dp[i][0] = i
            if i > 0 { bt[i][0] = .del }
        }
        for j in 0...n {
            dp[0][j] = j
            if j > 0 { bt[0][j] = .ins }
        }

        for i in 1...m {
            for j in 1...n {
                if ref[i - 1] == hyp[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                    bt[i][j] = .match
                } else {
                    let sub = dp[i - 1][j - 1] + 1
                    let ins = dp[i][j - 1] + 1
                    let del = dp[i - 1][j] + 1
                    let best = min(sub, ins, del)
                    dp[i][j] = best
                    bt[i][j] = (best == sub) ? .sub : (best == ins ? .ins : .del)
                }
            }
        }

        var steps: [Step] = []
        var i = m
        var j = n
        while i > 0 || j > 0 {
            let step = bt[i][j]
            steps.append(step)
            switch step {
            case .match, .sub:
                i -= (i > 0 ? 1 : 0)
                j -= (j > 0 ? 1 : 0)
            case .ins:
                j -= (j > 0 ? 1 : 0)
            case .del:
                i -= (i > 0 ? 1 : 0)
            }
        }

        steps.reverse()
        return (dp[m][n], steps)
    }

    private func buildPieces(_ ref: [String], _ hyp: [String], backtrace: [Step]) -> ([WordPiece], [WordPiece]) {
        var i = 0
        var j = 0
        var refPieces: [WordPiece] = []
        var hypPieces: [WordPiece] = []

        for step in backtrace {
            switch step {
            case .match:
                if i < ref.count { refPieces.append(.init(text: ref[i], isError: false)) }
                if j < hyp.count { hypPieces.append(.init(text: hyp[j], isError: false)) }
                i += 1
                j += 1
            case .sub:
                if i < ref.count { refPieces.append(.init(text: ref[i], isError: true)) }
                if j < hyp.count { hypPieces.append(.init(text: hyp[j], isError: true)) }
                i += 1
                j += 1
            case .ins:
                if j < hyp.count { hypPieces.append(.init(text: hyp[j], isError: true)) }
                j += 1
            case .del:
                if i < ref.count { refPieces.append(.init(text: ref[i], isError: true)) }
                i += 1
            }
        }

        return (refPieces, hypPieces)
    }
}
