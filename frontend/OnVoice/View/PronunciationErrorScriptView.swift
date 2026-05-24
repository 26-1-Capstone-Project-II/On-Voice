//
//  PronunciationErrorScriptView.swift
//  OnVoice
//
//  Created by Codex on 5/20/26.
//

import SwiftUI

struct PronunciationErrorScriptView: View {
    @Environment(\.dismiss) private var dismiss

    let script: PronunciationErrorScript
    let transcriptionFailure: TranscriptionFailure?
    let limitation: AnalysisLimitation?
    let onFinish: (() -> Void)?

    @State private var selectedSentenceID: UUID?
    @State private var isRecording = false
    @State private var attempts: [PronunciationPracticeAttempt] = []
    @State private var nextAttemptIndex = 0

    init(
        script: PronunciationErrorScript = .empty,
        transcriptionFailure: TranscriptionFailure? = nil,
        limitation: AnalysisLimitation? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.script = script
        self.transcriptionFailure = transcriptionFailure
        self.limitation = limitation
        self.onFinish = onFinish
    }

    private var selectedSentence: PronunciationErrorSentence? {
        guard let selectedSentenceID else { return nil }
        return script.sentences.compactMap(\.errorDetail).first { $0.id == selectedSentenceID }
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader

                if limitation == .intentTextUnavailable, !script.isEmpty {
                    limitationBanner
                }

                ZStack(alignment: .bottom) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            transcriptView(scrollProxy: proxy)
                                .padding(.horizontal, Layout.horizontalPadding)
                                .padding(.top, Layout.transcriptTopPadding)
                                .padding(.bottom, Layout.transcriptBottomPadding)
                        }
                    }

                    if script.isEmpty {
                        if let transcriptionFailure {
                            failureStateView(transcriptionFailure)
                        } else {
                            emptyStateView
                        }
                    }

                    if let selectedSentence {
                        outsideSheetDismissLayer

                        errorPracticeCard(selectedSentence)
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.bottom, Layout.practiceCardBottomPadding)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(2)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    /// 전사는 성공했지만 Apple ASR 의 의도 텍스트가 비어 G2P 비교가 비활성화된
    /// 경우의 안내 배너. 사용자는 자기 발화 텍스트만 볼 수 있고 오류 하이라이트는
    /// 사라지므로 왜 그런지 명시한다.
    private var limitationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.gray6)
            Text("의도된 발음을 인식하지 못해 오류 비교를 표시할 수 없어요.\n조용한 곳에서 다시 녹음하면 분석이 가능해요.")
                .font(.Pretendard.Medium.size14)
                .foregroundStyle(Color.gray6)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 10)
        .background(Color.gray10.opacity(0.6))
    }

    // 이 화면은 항상 분석 단계 이후 진입하고, Whisper 추론은 segment가 0개일 때도
    // .failure(.noSpeechDetected)로 매핑되어 failureStateView 분기로 흐른다.
    // 따라서 이 emptyStateView는 이론상 도달하지 않는 defensive 분기로만 남는다.
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("분석 결과가 비어있어요.")
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.sub)
            Text("앱을 재실행해도 같은 문제가 반복되면 개발팀에 알려 주세요.")
                .font(.Pretendard.Medium.size14)
                .foregroundStyle(Color.gray6)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, 80)
    }

    private func failureStateView(_ failure: TranscriptionFailure) -> some View {
        let style = Self.failureIcon(for: failure)
        return VStack(spacing: 8) {
            Image(systemName: style.name)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(style.color)
                .padding(.bottom, 4)
            Text(Self.failureTitle(for: failure))
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.sub)
            Text(Self.failureMessage(for: failure))
                .font(.Pretendard.Medium.size14)
                .foregroundStyle(Color.gray6)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, 80)
    }

    private static func failureIcon(for failure: TranscriptionFailure) -> (name: String, color: Color) {
        switch failure {
        case .modelMissing, .pipelineLoadFailed, .transcribeFailed:
            // 시스템/모델 단의 오류는 critical 톤(빨강 경고 아이콘).
            return ("exclamationmark.triangle", Color(hex: "#FF3867"))
        case .noSpeechDetected:
            // 발화가 비어있는 informational 케이스는 중립 톤(회색 마이크 아이콘).
            return ("mic.slash", Color.gray6)
        }
    }

    private static func failureTitle(for failure: TranscriptionFailure) -> String {
        switch failure {
        case .modelMissing:
            return "음성 인식 모델을 찾지 못했어요."
        case .pipelineLoadFailed:
            return "음성 인식 엔진을 불러오지 못했어요."
        case .transcribeFailed:
            return "녹음을 분석하지 못했어요."
        case .noSpeechDetected:
            return "분석할 발화가 없어요."
        }
    }

    private static func failureMessage(for failure: TranscriptionFailure) -> String {
        switch failure {
        case .modelMissing:
            return "앱을 다시 설치하거나, 개발 빌드라면 git lfs pull로 모델 파일을 받아 주세요."
        case .pipelineLoadFailed:
            return "앱을 재실행해도 같은 문제가 반복되면 개발팀에 알려 주세요."
        case .transcribeFailed:
            return "녹음을 다시 시도해 주세요. 반복되면 개발팀에 알려 주세요."
        case .noSpeechDetected:
            return "녹음에서 음성이 충분히 감지되지 않았어요.\n다시 녹음해 보세요."
        }
    }

    private var outsideSheetDismissLayer: some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissSelectedSentence()
            }
        .zIndex(1)
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

            Button("종료", action: handleFinishButtonTap)
            .font(.Pretendard.Medium.size16)
            .foregroundStyle(Color.main)
            .frame(width: 44, height: 44, alignment: .trailing)
        }
        .padding(.horizontal, Layout.navigationHorizontalPadding)
        .background(Color.bg)
    }

    private func transcriptView(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(script.sentences) { sentence in
                HighlightedText(
                    segments: sentence.segments,
                    font: .Pretendard.Medium.size20,
                    lineSpacing: 4
                )
                .opacity(transcriptOpacity(for: sentence))
                .fixedSize(horizontal: false, vertical: true)
                .id(sentence.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedSentenceID != nil {
                        dismissSelectedSentence()
                        return
                    }

                    guard let errorDetail = sentence.errorDetail else { return }
                    selectSentence(errorDetail)
                    scrollSelectedSentenceToTop(sentence.id, scrollProxy: scrollProxy)
                }
            }

            if selectedSentenceID != nil {
                // Forces enough scrollable content so a selected sentence can align to the top
                // even when the transcript itself is shorter than the visible area.
                Color.clear
                    .frame(height: UIScreen.main.bounds.height)
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
        // Temporary demo interaction. Real recording start/stop and silence detection
        // will be connected by the pronunciation model/audio integration task.
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
        guard let templates = selectedSentence?.dummyAttempts, !templates.isEmpty else { return }
        attempts = [templates[nextAttemptIndex % templates.count]]
        nextAttemptIndex += 1
    }

    private func transcriptOpacity(for sentence: PronunciationTranscriptSentence) -> Double {
        guard let selectedSentenceID else { return 1 }
        return sentence.errorDetail?.id == selectedSentenceID ? 1 : 0.5
    }

    private func selectSentence(_ sentence: PronunciationErrorSentence) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            selectedSentenceID = sentence.id
            attempts = []
            nextAttemptIndex = 0
            isRecording = false
        }
    }

    private func dismissSelectedSentence() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            selectedSentenceID = nil
            attempts = []
            nextAttemptIndex = 0
            isRecording = false
        }
    }

    private func handleFinishButtonTap() {
        dismissSelectedSentence()

        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func scrollSelectedSentenceToTop(_ id: UUID, scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.scrollToSelectedSentenceDelay) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                scrollProxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let navigationHorizontalPadding: CGFloat = 20
        static let transcriptTopPadding: CGFloat = 10
        static let transcriptBottomPadding: CGFloat = 34
        static let practiceCardBottomPadding: CGFloat = 8
        static let scrollToSelectedSentenceDelay: DispatchTimeInterval = .milliseconds(160)
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

#Preview {
    NavigationStack {
        PronunciationErrorScriptView(
            script: PronunciationErrorScript.makePlainScript(
                from: [
                    "오느른 키움 히어로즈랑 고처게서 경기를 하는데",
                    "아까 사회 초까지만 해도 쓰리런 치고 솔로포 치고 장난 아니언는데",
                    "점수 오점 먼저 낻따고 투수가 막 던져서 지금 오대오 동저미야."
                ]
            )
        )
    }
}
