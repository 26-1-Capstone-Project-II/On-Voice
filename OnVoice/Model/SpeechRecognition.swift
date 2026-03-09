//
//  SpeechRecognition.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//


import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognition: ObservableObject {
    // MARK: - Public published outputs
    
    @Published var appleTranscript: String = ""
    @Published var standardText: String = ""                // 표준 문장 (문법 수정된 버전)
    @Published var sentences: [SentenceComparison] = []     // 문장별 비교 결과
    @Published var overallAccuracy: Double = 0.0            // 0.0 ~ 1.0
    @Published var errorSentences: [SentenceComparison] = [] // 발음 오류가 있는 문장들만

    // MARK: - Entry
    
    /// 녹음 파일을 분석하여 표준 발음과 사용자 발음을 비교
    func analyze(url: URL, referenceText: String? = nil) async {
        // 1) 권한 확인
        await requestSTTAuthIfNeeded()
        
        // 2) Apple STT로 사용자 발음 인식
        let (userText, _) = (try? await transcribe(url: url)) ?? ("", [])
        self.appleTranscript = userText
        
        // 3) 표준 문장 생성 (사용자 제공 텍스트 또는 STT 결과를 문법적으로 수정)
        let standard = generateStandardText(from: referenceText ?? userText)
        self.standardText = standard
        
        // 4) 표준 발음 생성 (표준 문장을 발음기호로 변환)
        let standardPronunciation = generateStandardPronunciation(from: standard)
        
        // 5) 사용자 발음 텍스트 (STT 결과를 발음에 가깝게 변환)
        let userPronunciation = convertToPhoneticText(userText)
        
        // 6) 문장 단위 비교
        let comps = compareSentences(
            standardText: standard,
            standardPronunciation: standardPronunciation,
            userPronunciation: userPronunciation
        )
        self.sentences = comps
        
        // 7) 발음 오류가 있는 문장들만 필터링 (정확도 80% 미만)
        self.errorSentences = comps.filter { $0.accuracy < 0.8 }
        
        // 8) 전체 정확도 (문장 정확 판정 비율)
        let correctCount = comps.filter { $0.isCorrect }.count
        self.overallAccuracy = comps.isEmpty ? 0 : Double(correctCount) / Double(comps.count)
        
        // 9) STT 변환 결과 로깅
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎤 [STT 변환 결과 분석]")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 원본 STT 결과: \(userText)")
        print("📝 표준문장: \(standard)")
        print("🗣️ 표준발음: \(standardPronunciation)")
        print("👤 나의발음: \(userPronunciation)")
        print("📊 전체 정확도: \(String(format: "%.1f", overallAccuracy * 100))%")
        print("❌ 발음 오류 문장 수: \(errorSentences.count)개")

        // 문장별 상세 로깅
        for (index, sentence) in comps.enumerated() {
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

    // MARK: - Apple STT
    
    private func transcribe(url: URL) async throws -> (String, [SFTranscriptionSegment]) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")) else {
            return ("", [])
        }

        let request = SFSpeechURLRecognitionRequest(url: url)

        return try await withCheckedThrowingContinuation { cont in
            var didResume = false
            var bestText: String = ""
            var bestSegments: [SFTranscriptionSegment] = []

            let task = recognizer.recognitionTask(with: request) { result, error in
                if didResume { return }
                if let error = error {
                    didResume = true
                    cont.resume(returning: ("", []))
                    print("Apple STT error:", error)
                    return
                }
                guard let result = result else { return }

                bestText = result.bestTranscription.formattedString
                bestSegments = result.bestTranscription.segments

                if result.isFinal {
                    didResume = true
                    cont.resume(returning: (bestText, bestSegments))
                }
            }
            
            

            // 12초 타임아웃: 녹음 12초만 인식되는 문제 해결하기 위해서 주석 처리
//            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
//                if !didResume {
//                    task.cancel()
//                    didResume = true
//                    cont.resume(returning: (bestText, bestSegments))
//                }
//            }
        }
    }

    private func requestSTTAuthIfNeeded() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status != .authorized else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                cont.resume()
            }
        }
    }

    // MARK: - 텍스트 처리 함수들
    
    /// 표준 문장 생성 (기본적인 문법 교정)
    private func generateStandardText(from text: String) -> String {
        var corrected = text
        
        // 기본적인 문법 교정 규칙들
        corrected = corrected.replacingOccurrences(of: "됬", with: "됐")
        corrected = corrected.replacingOccurrences(of: "되여", with: "되어")
        corrected = corrected.replacingOccurrences(of: "하구", with: "하고")
        corrected = corrected.replacingOccurrences(of: "머구", with: "먹고")
        corrected = corrected.replacingOccurrences(of: "갔구", with: "갔고")
        
        // 띄어쓰기 정리
        corrected = corrected.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        corrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return corrected
    }
    
    /// 표준 발음 생성 (한글 표준 발음법 적용)
    private func generateStandardPronunciation(from text: String) -> String {
        // 한글 자모 배열 및 대응 표 준비
        let initialConsonants = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
        let medialVowels = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
        let finalConsonants = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ",
                                "ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ",
                                "ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
        // 복합 받침 분해 맵 (finalIndex -> (첫소리용, 둘째소리용 받침))
        let doubleFinalMap: [Int:(Int, Int)] = [
            3: (1, 19),   // ㄳ -> (ㄱ, ㅅ)
            5: (4, 22),   // ㄵ -> (ㄴ, ㅈ)
            6: (4, 27),   // ㄶ -> (ㄴ, ㅎ)
            9: (8, 1),    // ㄺ -> (ㄹ, ㄱ)
            10: (8, 16),  // ㄻ -> (ㄹ, ㅁ)
            11: (8, 17),  // ㄼ -> (ㄹ, ㅂ)
            12: (8, 19),  // ㄽ -> (ㄹ, ㅅ)
            13: (8, 25),  // ㄾ -> (ㄹ, ㅌ)
            14: (8, 26),  // ㄿ -> (ㄹ, ㅍ)
            15: (8, 27),  // ㅀ -> (ㄹ, ㅎ)
            18: (17, 19)  // ㅄ -> (ㅂ, ㅅ)
        ]
        // 받침 -> 초성 대응 (단일 받침에 한해 사용)
        let finalToInitial: [Int: Int] = [
            1: 0,   2: 1,   4: 2,   7: 3,   8: 5,
            16: 6,  17: 7,  19: 9,  20: 10, 21: 11,
            22: 12, 23: 14, 24: 15, 25: 16, 26: 17,
            27: 18
        ]
        
        // 1) 문자열을 음절 단위로 분해하여 initial, medial, final 인덱스로 저장
        struct Syllable { var initial: Int; var medial: Int; var final: Int; var isHangul: Bool; var char: Character }
        var syllables: [Syllable] = []
        for ch in text {
            if let scalar = ch.unicodeScalars.first,
               scalar.value >= 0xAC00 && scalar.value <= 0xD7A3 {
                // 한글 음절 분해
                let code = Int(scalar.value) - 0xAC00
                let finalIndex = code % 28
                let medialIndex = (code / 28) % 21
                let initialIndex = code / (28 * 21)
                syllables.append(Syllable(initial: initialIndex, medial: medialIndex,
                                           final: finalIndex, isHangul: true, char: ch))
            } else {
                // 한글 음절이 아닌 문자는 그대로 보존
                syllables.append(Syllable(initial: 0, medial: 0, final: 0,
                                           isHangul: false, char: ch))
            }
        }
        
        // 2) **연음 법칙 적용**: 받침 + (ㅇ으로 시작하는 모음)인 경우 받침 이동
        for i in 0..<(syllables.count - 1) {
            guard syllables[i].isHangul else { continue }
            // 다음 실제 한글 음절 위치 찾기 (공백/문장부호 건너뜀)
            var j = i + 1
            while j < syllables.count && !syllables[j].isHangul { j += 1 }
            guard j < syllables.count, syllables[j].isHangul else { continue }
            // 받침이 있고 다음 초성이 'ㅇ' (빈 초성)인 경우
            if syllables[i].final != 0 && syllables[j].initial == 11 {
                let fin = syllables[i].final
                if fin == 27 {
                    // 받침 ㅎ + 모음 -> ㅎ 발음 탈락
                    syllables[i].final = 0
                } else if let (firstFin, secondFin) = doubleFinalMap[fin] {
                    // 복합 받침의 경우
                    if secondFin == 27 {
                        // 받침 ㄶ, ㅀ: ㅎ 탈락, 첫소리 ㄴ/ㄹ만 남겨 이동
                        syllables[i].final = 0
                        if let newInit = finalToInitial[firstFin] {
                            syllables[j].initial = newInit
                        }
                    } else {
                        // 그 외 복합받침: 두 번째 받침 이동, 첫 번째 받침만 남김
                        syllables[i].final = firstFin
                        if let newInit = finalToInitial[secondFin] {
                            syllables[j].initial = newInit
                        }
                    }
                } else {
                    // 단일 받침 이동
                    // 받침 ㄷ/ㅌ + 모음 '이' -> 이동 후 구개음화 (ㄷ->ㅈ, ㅌ->ㅊ)
                    if (fin == 7 || fin == 25) && syllables[j].medial == 20 {
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
        
        // 3) **동화/축약 규칙 적용** (인접 음절 간 발음 변화)
        for i in 0..<(syllables.count - 1) {
            guard syllables[i].isHangul else { continue }
            var j = i + 1
            while j < syllables.count && !syllables[j].isHangul { j += 1 }
            guard j < syllables.count, syllables[j].isHangul else { continue }
            let fin = syllables[i].final   // 현재 음절 받침
            let initNext = syllables[j].initial  // 다음 음절 초성
            // (1) **자음동화 - ㅎ 거센소리화:** 받침 ㅎ (또는 ㄶ/ㅀ) + 다음 ㄱ,ㄷ,ㅂ,ㅈ -> 다음 초성을 ㅋ,ㅌ,ㅍ,ㅊ으로
            if fin == 27 && [0,3,7,12].contains(initNext) {
                // 단일 ㅎ 받침의 경우
                let aspiratedMap: [Int: Int] = [0:15, 3:16, 7:17, 12:14]  // ㄱ→ㅋ, ㄷ→ㅌ, ㅂ→ㅍ, ㅈ→ㅊ
                if let newInit = aspiratedMap[initNext] {
                    syllables[j].initial = newInit
                }
                syllables[i].final = 0  // ㅎ 소리는 사라짐
            } else if fin == 6 && [0,3,7,12].contains(initNext) {
                // 복합 받침 ㄶ + 다음 ㄱ,ㄷ,ㅂ,ㅈ -> ㄴ 남기고 다음 거센소리
                let aspiratedMap: [Int: Int] = [0:15, 3:16, 7:17, 12:14]
                if let newInit = aspiratedMap[initNext] {
                    syllables[j].initial = newInit
                }
                syllables[i].final = 4  // ㄶ 중 ㄴ만 남김
            } else if fin == 15 && [0,3,7,12].contains(initNext) {
                // 복합 받침 ㅀ + 다음 ㄱ,ㄷ,ㅂ,ㅈ -> ㄹ 남기고 다음 거센소리
                let aspiratedMap: [Int: Int] = [0:15, 3:16, 7:17, 12:14]
                if let newInit = aspiratedMap[initNext] {
                    syllables[j].initial = newInit
                }
                syllables[i].final = 8  // ㅀ 중 ㄹ만 남김
            }
            // (2) **자음동화 - 받침+ㅎ 축약:** 받침이 ㄱ,ㄷ,ㅂ 등 폐음+ 다음 초성 ㅎ -> 받침과 ㅎ이 합쳐져 거센소리
            if initNext == 18 && ![0,4,8,16,21,27].contains(fin) {
                // (초성 ㅎ이고, 앞 음절 받침이 없거나 (0), 비음/유음(4,8,16,21) 또는 ㅎ(27)이 아닌 경우)
                var baseFin = fin
                if let (firstFin, secondFin) = doubleFinalMap[fin] {
                    // 복합받침인 경우 -> 발음되는 대표 자음으로 간주
                    switch fin {
                    case 11, 14:   // ㄼ, ㄿ (실제로는 ㄹ+ㅂ, ㄹ+ㅍ)
                        baseFin = 17   // ㅂ 계열로 취급
                    case 12, 13:   // ㄽ, ㄾ (ㄹ+ㅅ, ㄹ+ㅌ)
                        baseFin = 8    // ㄹ로 취급
                    case 3, 9:     // ㄳ, ㄺ
                        baseFin = 1    // ㄱ으로 취급
                    case 18:       // ㅄ
                        baseFin = 17   // ㅂ으로 취급
                    default:
                        baseFin = firstFin
                    }
                }
                // baseFin에 따라 초성 변경: ㄱ,ㄲ,ㅋ 계열 -> ㅋ / ㄷ,ㅌ,ㅅ,ㅆ,ㅈ,ㅊ 계열 -> ㅌ / ㅂ,ㅍ 계열 -> ㅍ
                if [1,2,24].contains(baseFin) {
                    syllables[j].initial = 15  // ㅋ
                } else if [7,25,19,20,22,23].contains(baseFin) {
                    syllables[j].initial = 16  // ㅌ
                } else if [17,26].contains(baseFin) {
                    syllables[j].initial = 17  // ㅍ
                }
                syllables[i].final = 0
            }
            // (3) **비음화:** 받침 + ㄴ/ㅁ -> 받침을 비음(ㄴ,ㅁ,ㅇ)으로
            if [2,6].contains(initNext) {
                if [1,2,24].contains(fin) {
                    syllables[i].final = 21   // ㄱ,ㄲ,ㅋ + ㄴ/ㅁ -> ㅇ (예: 국물→궁물)
                } else if [7,25,19,20,22,23].contains(fin) {
                    syllables[i].final = 4    // ㄷ,ㅌ,ㅅ,ㅆ,ㅈ,ㅊ + ㄴ/ㅁ -> ㄴ (예: 꽂는→꼰는)
                } else if [17,26].contains(fin) {
                    syllables[i].final = 16   // ㅂ,ㅍ + ㄴ/ㅁ -> ㅁ (예: 밥물→밤물)
                } else if fin == 3 {
                    syllables[i].final = 21   // ㄳ + ㄴ/ㅁ -> ㄱ->ㅇ
                } else if fin == 18 {
                    syllables[i].final = 16   // ㅄ + ㄴ/ㅁ -> ㅂ->ㅁ
                }
                if fin == 6 {
                    syllables[i].final = 4    // ㄶ + ㄴ/ㅁ -> ㄴ (ㅎ 탈락)
                } else if fin == 15 {
                    syllables[i].final = 8    // ㅀ + ㄴ/ㅁ -> ㄹ (ㅎ 탈락)
                }
            }
            // (4) **유음화:** ㄴ+ㄹ 또는 ㄹ+ㄴ -> 둘 다 ㄹ로 발음
            if fin == 4 && initNext == 5 {
                syllables[i].final = 8       // final ㄴ -> ㄹ (예: 신라→실라)
            }
            if fin == 8 && initNext == 2 {
                syllables[j].initial = 5     // initial ㄴ -> ㄹ (예: 설날→설랄)
            }
            // (5) **ㄹ + 비음 동화:** 받침 ㄴ/ㅁ/ㅇ + 다음 초성 ㄹ -> 초성 ㄹ를 ㄴ으로
            if [4,16,21].contains(fin) && initNext == 5 {
                syllables[j].initial = 2     // ㄹ -> ㄴ (예: 공로→공노, 심리→심니)
            }
            // (6) **경음화(된소리되기):** 받침 (예사소리) + 다음 예사소리 초성 -> 초성을 된소리화
            if initNext == 5 && ![0,4,8,16,21,27].contains(fin) {
                // 특별 규칙: 받침 + ㄹ (두음법칙에 따라 앞에서 처리) 제외, 여기서는 대상 아님
                // => 위 (5) 단계에서 이미 ㄹ->ㄴ 처리되므로 넘어감
            }
            if [0,3,7,9,12].contains(initNext) && ![0,4,6,8,15,16,21,27].contains(fin) {
                let tenseMap: [Int: Int] = [0:1, 3:4, 7:8, 9:10, 12:13]  // ㄱ→ㄲ, ㄷ→ㄸ, ㅂ→ㅃ, ㅅ→ㅆ, ㅈ→ㅉ
                if let newInit = tenseMap[initNext] {
                    syllables[j].initial = newInit
                }
            }
            // **추가: 거센소리의 된소리화** – 받침 뒤의 ㅋ, ㅍ도 된소리로 발음되는 경우 처리
            if initNext == 15 && ![0,4,6,8,15,16,21,27].contains(fin) {
                syllables[j].initial = 1    // ㅋ -> ㄲ (예: 부엌칼→부엌깔)
            }
            if initNext == 17 && ![0,4,6,8,15,16,21,27].contains(fin) {
                syllables[j].initial = 8    // ㅍ -> ㅃ (예: 작품→작뿜)
            }
        }
        
        // 4) 수정된 initial/medial/final 배열을 다시 한글 문자열로 합성
        var result = ""
        for syl in syllables {
            if syl.isHangul {
                let unicodeValue = syl.initial * 21 * 28 + syl.medial * 28 + syl.final + 0xAC00
                if let scalar = UnicodeScalar(unicodeValue) {
                    result.append(Character(scalar))
                }
            } else {
                result.append(syl.char)  // 공백이나 기타 문자 그대로 추가
            }
        }
        return result
    }
    
    /// 사용자 발음을 음성학적 텍스트로 변환
    private func convertToPhoneticText(_ text: String) -> String {
        // STT 결과를 그대로 사용 (실제 발음에 가까움)
        return text
    }

    // MARK: - 문장 비교
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
        return results.filter { !$0.reference.isEmpty } // 빈 문장 제거
    }

    // MARK: - Utilities
    
    private func sentenceSplit(_ text: String) -> [String] {
        return text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".?!。？！"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func tokenize(_ sentence: String) -> [String] {
        let trimmed = sentence.lowercased()
        let cleaned = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return cleaned
    }

    // 편집거리 + 경로 (삽입/삭제/치환)
    private enum Step { case match, sub, ins, del }

    private func editDistanceWithPath(_ ref: [String], _ hyp: [String]) -> (Int, [Step]) {
        let m = ref.count, n = hyp.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        var bt = Array(repeating: Array(repeating: Step.match, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = i; if i > 0 { bt[i][0] = .del } }
        for j in 0...n { dp[0][j] = j; if j > 0 { bt[0][j] = .ins } }

        for i in 1...m {
            for j in 1...n {
                if ref[i-1] == hyp[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                    bt[i][j] = .match
                } else {
                    let sub = dp[i-1][j-1] + 1
                    let ins = dp[i][j-1] + 1
                    let del = dp[i-1][j] + 1
                    let best = min(sub, ins, del)
                    dp[i][j] = best
                    bt[i][j] = (best == sub) ? .sub : (best == ins ? .ins : .del)
                }
            }
        }

        // backtrace
        var steps: [Step] = []
        var i = m, j = n
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
        var i = 0, j = 0
        var refPieces: [WordPiece] = []
        var hypPieces: [WordPiece] = []

        for step in backtrace {
            switch step {
            case .match:
                if i < ref.count { refPieces.append(.init(text: ref[i], isError: false)) }
                if j < hyp.count { hypPieces.append(.init(text: hyp[j], isError: false)) }
                i += 1; j += 1
            case .sub:
                if i < ref.count { refPieces.append(.init(text: ref[i], isError: true)) }
                if j < hyp.count { hypPieces.append(.init(text: hyp[j], isError: true)) }
                i += 1; j += 1
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

// MARK: - Models
struct WordPiece: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct SentenceComparison: Identifiable {
    let id = UUID()
    let index: Int
    let reference: String              // 표준문장
    let standardPronunciation: String  // 표준발음
    let hypothesis: String             // 나의발음
    let referencePieces: [WordPiece]
    let hypothesisPieces: [WordPiece]
    let accuracy: Double               // 0~1
    let isCorrect: Bool                // 임계값 이상이면 true
}
