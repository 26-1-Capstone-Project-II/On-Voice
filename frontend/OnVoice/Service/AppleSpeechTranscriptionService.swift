//
//  AppleSpeechTranscriptionService.swift
//  OnVoice
//
//  Created by Codex on 3/9/26.
//

import Foundation
import Speech

final class AppleSpeechTranscriptionService {
    func requestAuthorizationIfNeeded() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status != .authorized else { return }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                cont.resume()
            }
        }
    }

    func transcribe(url: URL) async -> (String, [SFTranscriptionSegment]) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")) else {
            return ("", [])
        }

        let request = SFSpeechURLRecognitionRequest(url: url)

        return await withCheckedContinuation { cont in
            var didResume = false
            var bestText = ""
            var bestSegments: [SFTranscriptionSegment] = []

            _ = recognizer.recognitionTask(with: request) { result, error in
                if didResume { return }

                if let error {
                    didResume = true
                    print("Apple STT error:", error)
                    cont.resume(returning: ("", []))
                    return
                }

                guard let result else { return }

                bestText = result.bestTranscription.formattedString
                bestSegments = result.bestTranscription.segments

                if result.isFinal {
                    didResume = true
                    cont.resume(returning: (bestText, bestSegments))
                }
            }
        }
    }
}
