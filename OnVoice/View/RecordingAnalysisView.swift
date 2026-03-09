//
//  RecordingAnalysisView.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//

import SwiftUI

struct RecordingAnalysisView: View {
    @ObservedObject var viewModel: RecordingAnalysisViewModel
    @StateObject private var practiceViewModel = PronunciationPracticeViewModel()
    @State private var currentSentenceIndex = 0

    // 네비게이션 환경 변수
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    // 현재 문장 정보
    private var currentSentence: SentenceComparison? {
        guard currentSentenceIndex < viewModel.errorSentences.count else { return nil }
        return viewModel.errorSentences[currentSentenceIndex]
    }

    // 마지막 문장인지 확인
    private var isLastSentence: Bool {
        currentSentenceIndex == viewModel.errorSentences.count - 1
    }

    // 녹음 버튼 활성화 조건
    private var canRecord: Bool {
        // 목표 달성했으면 녹음 불가, 4회 완료했으면 5번째부터 연습 가능
        !practiceViewModel.hasReachedTarget
    }

    // 다음 버튼 활성화 조건
    private var canProceedToNext: Bool {
        // 목표 달성했거나, 4회 완료했으면 다음으로 이동 가능
        practiceViewModel.hasReachedTarget || practiceViewModel.hasCompletedFourAttempts
    }

    // 다음 버튼 텍스트
    private var nextButtonText: String {
        isLastSentence ? "종료" : "다음"
    }

    var body: some View {
        ZStack {
            Color.suBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 네비게이션
                navigationHeader

                // 메인 콘텐츠
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let sentence = currentSentence {
                            // 문장 정보 표시
                            sentenceInfoView(sentence)

                            // 발음 연습 상태
                            practiceStatusView

                            // 연습 결과 (있는 경우)
                            if practiceViewModel.practiceCount > 0 {
                                practiceResultView
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                // 하단 버튼들
                bottomButtonsView
            }
        }
//        .navigationTitle("발음 연습하기")
//        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .overlay {
            if viewModel.isLoading || viewModel.analysis == nil {
                ProgressView("분석 중…")
                    .progressViewStyle(.circular)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Navigation Header
    private var navigationHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
            }

            Spacer()

            Text("발음 연습하기")
                .font(.Pretendard.Bold.size18)
                .foregroundColor(.white)

            Spacer()

            // 마지막 문장이 아닐 때만 종료 버튼 표시
            if !isLastSentence {
                Button("종료") {
                    // HomeView로 돌아가기
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
                .font(.Pretendard.Medium.size16)
            } else {
                // 마지막 문장에서는 종료 버튼 숨김
                Color.clear
                    .frame(width: 40)
            }
        }
//        .padding(.horizontal, 20)
//        .padding(.top, 10)
//        .padding(.bottom, 20)
    }

    // MARK: - Sentence Info View
    private func sentenceInfoView(_ sentence: SentenceComparison) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 표준문장
            VStack(alignment: .leading, spacing: 8) {
                Text("표준문장")
                    .font(.Pretendard.SemiBold.size16)
                    .foregroundColor(.suGray2)

                Text(sentence.reference)
                    .font(.Pretendard.Regular.size16)
                    .foregroundColor(.white)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.suGray7)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 표준발음
            VStack(alignment: .leading, spacing: 8) {
                Text("표준발음")
                    .font(.Pretendard.SemiBold.size16)
                    .foregroundColor(.suGray2)

                Text(sentence.standardPronunciation)
                    .font(.Pretendard.Regular.size16)
                    .foregroundColor(.white)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.suGray7)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 나의 발음 (발음 오류 지점 하이라이트)
            VStack(alignment: .leading, spacing: 8) {
                Text("나의 발음")
                    .font(.Pretendard.SemiBold.size16)
                    .foregroundColor(.suGray2)

                TokenDiffText(pieces: sentence.hypothesisPieces)
            }
        }
    }

    // MARK: - Practice Status View
    private var practiceStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습 현황")
                .font(.Pretendard.SemiBold.size16)
                .foregroundColor(.suGray2)

            HStack {
                Text("연습 횟수: \(practiceViewModel.practiceCount)/4")
                    .font(.Pretendard.Medium.size14)
                    .foregroundColor(.white)

                Spacer()

                if practiceViewModel.hasReachedTarget {
                    Text("목표 달성! 🎉")
                        .font(.Pretendard.Bold.size14)
                        .foregroundColor(.point)
                } else if practiceViewModel.practiceCount >= 4 {
                    Text("4회 완료 - 계속 연습 가능")
                        .font(.Pretendard.Medium.size14)
                        .foregroundColor(.suGray3)
                }
            }
            .padding(12)
            .background(Color.suGray7)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Practice Result View
    private var practiceResultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습 결과")
                .font(.Pretendard.SemiBold.size16)
                .foregroundColor(.suGray2)

            VStack(alignment: .leading, spacing: 8) {
                Text("인식된 발음: \(practiceViewModel.recognizedText)")
                    .font(.Pretendard.Regular.size14)
                    .foregroundColor(.white)

                Text("정확도: \(Int(practiceViewModel.currentAccuracy))%")
                    .font(.Pretendard.Medium.size14)
                    .foregroundColor(practiceViewModel.currentAccuracy >= 80 ? .point : .red)
            }
            .padding(12)
            .background(Color.suGray7)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Bottom Buttons View
    private var bottomButtonsView: some View {
        VStack(spacing: 16) {
            // 녹음 버튼
            Button(action: {
                if !practiceViewModel.isRecording {
                    Task {
                        if let sentence = currentSentence {
                            await practiceViewModel.startPractice(
                                standardPronunciation: sentence.standardPronunciation
                            )
                        }
                    }
                } else {
                    Task {
                        await practiceViewModel.stopRecording()
                    }
                }
            }) {
                Image(systemName: practiceViewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(practiceViewModel.isRecording ? .red : (canRecord ? .point : .suGray6))
            }
            .disabled(!canRecord && !practiceViewModel.isRecording)

            // 다음/종료 버튼
            Button(action: {
                if isLastSentence {
                    // 종료 - HomeView로 돌아가기
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // 다음 문장으로 이동
                    moveToNextSentence()
                }
            }) {
                Text(nextButtonText)
                    .font(.Pretendard.Bold.size18)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceedToNext ? Color.point : Color.suGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceedToNext)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Methods
    private func moveToNextSentence() {
        if currentSentenceIndex < viewModel.errorSentences.count - 1 {
            currentSentenceIndex += 1
            practiceViewModel.resetPractice()
        }
    }
}

struct TokenDiffText: View {
    let pieces: [WordPiece]
    var body: some View {
        let views = pieces.map { piece in
            Text(piece.text)
                .foregroundStyle(piece.isError ? Color.red : Color.white)
                .font(.Pretendard.Regular.size16)
                + Text(" ")
        }
        return views.reduce(Text(""), +)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.suGray6)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
