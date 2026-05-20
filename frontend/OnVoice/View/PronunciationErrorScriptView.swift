//
//  PronunciationErrorScriptView.swift
//  OnVoice
//
//  Created by Codex on 5/20/26.
//

import SwiftUI

struct PronunciationErrorScriptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedSentenceID: UUID?
    @State private var isRecording = false
    @State private var attempts: [PronunciationPracticeAttempt] = []
    @State private var nextAttemptIndex = 0

    private let script = PronunciationErrorScript.sample

    private var selectedSentence: PronunciationErrorSentence? {
        guard let selectedSentenceID else { return nil }
        return script.sentences.compactMap(\.errorDetail).first { $0.id == selectedSentenceID }
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader

                ZStack(alignment: .bottom) {
                    ScrollView(showsIndicators: false) {
                        transcriptView
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .padding(.bottom, selectedSentence == nil ? 34 : 430)
                    }

                    if let selectedSentence {
                        errorPracticeCard(selectedSentence)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    private var navigationHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.main)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("오류 발음 스크립트")
                .font(.Pretendard.SemiBold.size18)
                .foregroundStyle(Color.sub)

            Spacer()

            Button("종료") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.Pretendard.Medium.size16)
            .foregroundStyle(Color.main)
            .frame(width: 44, height: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .background(Color.bg)
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(script.sentences) { sentence in
                HighlightedText(
                    segments: sentence.segments,
                    font: .Pretendard.Medium.size20,
                    lineSpacing: 4
                )
                .opacity(transcriptOpacity(for: sentence))
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let errorDetail = sentence.errorDetail else { return }
                    selectSentence(errorDetail)
                }
            }
        }
    }

    private func errorPracticeCard(_ sentence: PronunciationErrorSentence) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 20) {
                tagRow(sentence.errorTypes)

                VStack(alignment: .leading, spacing: 18) {
                    HighlightedText(
                        segments: sentence.originalSegments,
                        font: .Pretendard.Medium.size16,
                        lineSpacing: 0
                    )
                    .opacity(attempts.isEmpty ? 1 : 0.5)

                    Text("올바른 발음")
                        .font(.Pretendard.Medium.size14)
                        .foregroundStyle(Color.sub)

                    HighlightedText(
                        segments: sentence.correctSegments,
                        font: .Pretendard.SemiBold.size18,
                        lineSpacing: 0
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.gray8.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 16) {
                HighlightedText(
                    segments: sentence.userAttemptSegments,
                    font: .Pretendard.SemiBold.size18,
                    lineSpacing: 0
                )
                .opacity(attempts.isEmpty ? 1 : 0.5)

                ForEach(attempts) { attempt in
                    HighlightedText(
                        segments: attempt.segments,
                        font: .Pretendard.SemiBold.size18,
                        lineSpacing: 0
                    )
                    .opacity(attempt.id == attempts.last?.id ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 18)

            HStack(alignment: .bottom) {
                if isRecording {
                    VoiceWaveformView()
                        .frame(width: 58, height: 38)
                        .padding(.leading, 14)
                        .transition(.opacity)
                }

                Spacer()

                practiceButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.gray10)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tagRow(_ tags: [PronunciationErrorType]) -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            ForEach(tags.prefix(3)) { tag in
                Text(tag.title)
                    .font(.Pretendard.Medium.size14)
                    .foregroundStyle(tag.isDifficult ? tag.accentColor : Color.sub.opacity(0.86))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(tag.isDifficult ? tag.accentColor.opacity(0.3) : Color.sub.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var practiceButton: some View {
        Button {
            toggleDummyPractice()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mic")
                    .font(.system(size: 16, weight: .medium))

                Text("발음 연습하기")
                    .font(.Pretendard.Medium.size16)
            }
            .foregroundStyle(Color.sub.opacity(isRecording ? 0.5 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray10)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.main.opacity(isRecording ? 0.5 : 1), lineWidth: 1)
            }
            .opacity(isRecording ? 0.5 : 1)
        }
    }

    private func toggleDummyPractice() {
        if isRecording {
            appendDummyAttempt()
            withAnimation(.easeInOut(duration: 0.18)) {
                isRecording = false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                isRecording = true
            }
        }
    }

    private func appendDummyAttempt() {
        let templates = selectedSentence?.dummyAttempts ?? PronunciationPracticeAttempt.samples
        attempts = [templates[nextAttemptIndex % templates.count]]
        nextAttemptIndex += 1
    }

    private func transcriptOpacity(for sentence: PronunciationTranscriptSentence) -> Double {
        guard let selectedSentenceID else { return 1 }
        return sentence.errorDetail?.id == selectedSentenceID ? 1 : 0.5
    }

    private func selectSentence(_ sentence: PronunciationErrorSentence) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            if selectedSentenceID == sentence.id {
                selectedSentenceID = nil
                attempts = []
                nextAttemptIndex = 0
                isRecording = false
                return
            }

            selectedSentenceID = sentence.id
            attempts = []
            nextAttemptIndex = 0
            isRecording = false
        }
    }
}

private struct HighlightedText: View {
    let segments: [PronunciationTextSegment]
    let font: Font
    let lineSpacing: CGFloat

    var body: some View {
        segments
            .reduce(Text("")) { result, segment in
                result + Text(segment.text)
                    .foregroundStyle(segment.color)
                    .font(font)
            }
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VoiceWaveformView: View {
    @State private var isAnimating = false

    private let heights: [CGFloat] = [16, 28, 20, 34, 26, 18, 24]

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.sub)
                    .frame(width: 3, height: isAnimating ? heights[index] : heights.reversed()[index])
                    .animation(
                        .easeInOut(duration: 0.42)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct PronunciationErrorScript {
    let sentences: [PronunciationTranscriptSentence]

    static let sample: PronunciationErrorScript = {
        let hungerError = PronunciationErrorSentence.hungerSample
        let baseballError = PronunciationErrorSentence.baseballSample

        return PronunciationErrorScript(sentences: [
            PronunciationTranscriptSentence(segments: [
                .normal("사실 오늘 너무 배고파서 점심 먹고 나서도 맥도날드 가서 베이컨 토마토 디럭스 세트에 스낵랩까지 먹었잖아. ")
            ]),
            PronunciationTranscriptSentence(
                segments: [
                    .normal("근데도 저녁 시간 됐다고 "),
                    .error("어떻게"),
                    .normal(" 바로 배고프냐. ")
                ],
                errorDetail: hungerError
            ),
            PronunciationTranscriptSentence(segments: [
                .normal("나 요즘 야구에 빠져 가지고 6시 30분만 되면 음식 들고 TV 앞에 앉아야 돼. 그래서 그런가? 진짜 6시 30분만 되면 밥을 먹어야될 것 같아서 그런지 그 이전에 뭘 먹든 일단 그 때만 되면 배고파. ")
            ]),
            PronunciationTranscriptSentence(
                segments: [
                    .normal("오늘은 "),
                    .error("키움 히어로즈랑"),
                    .normal(" 고척에서 경기를 "),
                    .error("하는데"),
                    .normal(" 아까 "),
                    .error("4회 초까지만 해도"),
                    .normal(" 쓰리런 치고 "),
                    .error("솔로포"),
                    .normal(" 치고 "),
                    .error("장난 아니었는데"),
                    .normal(" 점수 5점 먼저 냈다고 "),
                    .error("투수가"),
                    .normal(" 막 던져서 지금 5대5 "),
                    .error("동점이야"),
                    .normal(". ")
                ],
                errorDetail: baseballError
            ),
            PronunciationTranscriptSentence(segments: [
                .normal("오늘 선발 최민석이라 그래도 믿었는데 4회만에 내려갔어.")
            ])
        ])
    }()
}

private struct PronunciationTranscriptSentence: Identifiable {
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

private struct PronunciationErrorSentence: Identifiable {
    let id = UUID()
    let originalSegments: [PronunciationTextSegment]
    let correctSegments: [PronunciationTextSegment]
    let userAttemptSegments: [PronunciationTextSegment]
    let errorTypes: [PronunciationErrorType]
    let dummyAttempts: [PronunciationPracticeAttempt]

    static let hungerSample = PronunciationErrorSentence(
        originalSegments: [
            .muted("근데도 저녁 시간 됐다고 어떻게 바로 배고프냐.")
        ],
        correctSegments: [
            .normal("근데도 저녁 시간 됃따고 "),
            .normal("어떠케"),
            .normal(" 바로 배고프냐.")
        ],
        userAttemptSegments: [
            .normal("근데도 저녁 시간 됃따고 "),
            .error("어떠게"),
            .normal(" 바로 배고프냐.")
        ],
        errorTypes: [
            PronunciationErrorType(title: "혼/겹모음 혼동", isDifficult: false),
            PronunciationErrorType(title: "초성 대치", isDifficult: true)
        ],
        dummyAttempts: [
            PronunciationPracticeAttempt(
                segments: [
                    .normal("근데도 저녁 시간 됃따고 "),
                    .error("어떠게"),
                    .normal(" 바로 배고프냐.")
                ]
            ),
            PronunciationPracticeAttempt(
                segments: [
                    .normal("근데도 저녁 시간 됃따고 "),
                    .success("어떠케"),
                    .normal(" 바로 배고프냐.")
                ]
            )
        ]
    )

    static let baseballSample = PronunciationErrorSentence(
        originalSegments: [
            .muted("오늘은 키움 히어로즈랑 고척에서 경기를 하는데 아까 4회 초까지만 해도 쓰리런 치고 솔로포 치고 장난 아니었는데 점수 5점 먼저 냈다고 투수가 막 던져서 지금 5대5 동점이야.")
        ],
        correctSegments: [
            .normal("오느른 "),
            .normal("키움"),
            .normal(" 히어로즈랑 고처게서 경기를 하는데 아까 사회 초까지만 해도 쓰리런 치고 솔로포 치고 장난 아니언는데 오점 먼저 낻따고 투수가 막 던져서 지금 오대오 동저미야.")
        ],
        userAttemptSegments: [
            .normal("오느른 "),
            .error("기움"),
            .normal(" 히어로즈랑 고처게서 경기를 하는데 아까 사"),
            .error("에"),
            .normal(" 초까지"),
            .error("마 내"),
            .normal("도 쓰리런 치고 솔로"),
            .error("보"),
            .normal(" 치고 장"),
            .error("다 아디어드데"),
            .normal(" 오점 먼저 낻따고 투"),
            .error("슈"),
            .normal("가 막 던저서 지금 오대오 동저"),
            .error("비"),
            .normal("야.")
        ],
        errorTypes: [
            PronunciationErrorType(title: "혼/겹모음 혼동", isDifficult: false),
            PronunciationErrorType(title: "종성 오류", isDifficult: true),
            PronunciationErrorType(title: "초성 대치", isDifficult: false)
        ],
        dummyAttempts: PronunciationPracticeAttempt.samples
    )
}

private struct PronunciationPracticeAttempt: Identifiable {
    let id = UUID()
    let segments: [PronunciationTextSegment]

    static let samples: [PronunciationPracticeAttempt] = [
        PronunciationPracticeAttempt(
            segments: [
                .success("오느른 "),
                .error("기움"),
                .success(" 히어로즈랑 고처게서 경기를 "),
                .error("아드데"),
                .success(" 아까 사에 초까지마 "),
                .error("내"),
                .success("도 쓰리런 치고 솔로"),
                .error("보"),
                .success(" 치고 장"),
                .error("다"),
                .success(" 아니언드데 오점 먼저 낻따고 투"),
                .error("슈"),
                .success("가 막 던저서 지금 오대오 동저"),
                .error("비"),
                .success("야.")
            ]
        ),
        PronunciationPracticeAttempt(
            segments: [
                .success("오느른 "),
                .success("키움 히어로즈랑"),
                .success(" 고처게서 경기를 "),
                .error("아드데"),
                .success(" 아까 사헤 초까지마 "),
                .success("해도"),
                .success(" 쓰리런 치고 솔로"),
                .error("보"),
                .success(" 치고 장"),
                .success("난 아니언는데"),
                .success(" 오점 먼저 낻따고 투스가 막 던저서 지금 오대오 동저미야.")
            ]
        )
    ]
}

private struct PronunciationErrorType: Identifiable {
    let id = UUID()
    let title: String
    let isDifficult: Bool
    let accentColor = Color(hex: "#FFA0A0")
}

private struct PronunciationTextSegment: Identifiable {
    let id = UUID()
    let text: String
    let color: Color

    static func normal(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, color: Color.sub)
    }

    static func muted(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, color: Color.gray6)
    }

    static func error(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, color: Color(hex: "#FF3867"))
    }

    static func emphasis(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, color: Color.main)
    }

    static func success(_ text: String) -> PronunciationTextSegment {
        PronunciationTextSegment(text: text, color: Color.main)
    }
}

#Preview {
    NavigationStack {
        PronunciationErrorScriptView()
    }
}
