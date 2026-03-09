//
//  PronunciationAssessmentService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation

final class PronunciationAssessmentService {
    private let transcriptionService: AppleSpeechTranscriptionService

    init(transcriptionService: AppleSpeechTranscriptionService = AppleSpeechTranscriptionService()) {
        self.transcriptionService = transcriptionService
    }

    func evaluatePractice(recordingURL: URL, standardText: String) async -> PracticeEvaluationResult {
        await transcriptionService.requestAuthorizationIfNeeded()

        let (recognizedText, _) = await transcriptionService.transcribe(url: recordingURL)
        let accuracy = accuracyPercent(standard: standardText, hypothesis: recognizedText)

        return PracticeEvaluationResult(recognizedText: recognizedText, accuracy: accuracy)
    }

    private func accuracyPercent(standard: String, hypothesis: String) -> Double {
        let ref = tokenize(standard)
        let hyp = tokenize(hypothesis)
        let matched = lcs(a: ref, b: hyp)
        let denominator = max(ref.count, hyp.count, 1)
        return (Double(matched) / Double(denominator)) * 100.0
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[^ㄱ-ㅎ가-힣0-9a-z\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    private func lcs(a: [String], b: [String]) -> Int {
        let n = a.count
        let m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        for i in 1...n {
            for j in 1...m {
                dp[i][j] = (a[i - 1] == b[j - 1]) ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1])
            }
        }

        return dp[n][m]
    }
}
