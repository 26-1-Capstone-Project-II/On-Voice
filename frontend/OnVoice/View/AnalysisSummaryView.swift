//
//  AnalysisSummaryView.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//

import SwiftUI

struct AnalysisSummaryView: View {
    @StateObject private var viewModel: RecordingAnalysisViewModel
    @State private var expandedItemID: String?
    @State private var goToPractice = false
    let onFinish: (() -> Void)?

    init(recording: Recording, onFinish: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: RecordingAnalysisViewModel(recording: recording))
        self.onFinish = onFinish
    }

    private var score: Int {
        guard let analysis = viewModel.analysis, analysis.isPronunciationEvaluationAvailable else {
            return 54
        }

        return Int((analysis.overallAccuracy * 100).rounded())
    }

    private var scoreLevel: PronunciationScoreLevel {
        PronunciationScoreLevel(score: score)
    }

    private var difficultyItems: [PronunciationDifficultyItem] {
        PronunciationDifficultyItem.samples
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        scoreSection
                        difficultySection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 96)
                }

                bottomButton
            }

            if viewModel.isLoading && viewModel.analysis == nil {
                ProgressView("분석 중...")
                    .progressViewStyle(.circular)
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("나의 발음 분석 리포트")
                    .font(.Pretendard.SemiBold.size18)
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("나의 발음 평가 점수")
                .font(.Pretendard.SemiBold.size16)
                .foregroundColor(.white)

            VStack(spacing: 20) {
                PronunciationDonutChart(
                    score: score,
                    progressColor: scoreLevel.color
                )
                .frame(width: 130, height: 130)

                VStack(spacing: 12) {
                    Text(scoreLevel.title)
                        .font(.Pretendard.SemiBold.size18)
                        .foregroundColor(.white)

                    Text("받침 발음을 가장 어려워하고 있어요.\n목소리에 힘을 주고, 단어를 끝까지 소리낸다는\n방식으로 발음을 연습해보면 좋을 것 같아요.")
                        .font(.Pretendard.Medium.size16)
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
            .background(Color.gray10)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("내가 어려워하는 발음")
                .font(.Pretendard.SemiBold.size16)
                .foregroundColor(.white)

            LazyVStack(spacing: 16) {
                ForEach(difficultyItems) { item in
                    PronunciationDifficultyRow(
                        item: item,
                        isExpanded: expandedItemID == item.id
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            expandedItemID = expandedItemID == item.id ? nil : item.id
                        }
                    }
                }
            }
        }
    }

    private var bottomButton: some View {
        VStack(spacing: 0) {
            NavigationLink(isActive: $goToPractice) {
                PronunciationErrorScriptView(
                    script: viewModel.analysis?.scriptAnalysis ?? .empty,
                    transcriptionFailure: viewModel.analysis?.transcriptionFailure,
                    limitation: viewModel.analysis?.limitation,
                    onFinish: onFinish
                )
            } label: {
                EmptyView()
            }

            Button {
                goToPractice = true
            } label: {
                Text("오류 발음 확인하기")
                    .font(.Pretendard.SemiBold.size18)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.main)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(Color.bg)
        }
    }
}

// PronunciationScoreLevel 은 Model/AnalysisSummary.swift 로 승격됨.
// "내가 어려워하는 발음" 카드 데이터(PronunciationDifficultyItem) 는 sub-issue 2 에서
// 모델의 PronunciationDifficultyResult 로 교체될 예정.

private struct PronunciationDifficultyItem: Identifiable {
    let id: String
    let rank: Int
    let title: String
    let subtitle: String
    let practiceTitle: String
    let guideText: String
    let accentColor: Color
    let imageName: String

    static let samples: [PronunciationDifficultyItem] = [
        PronunciationDifficultyItem(
            id: "final-consonant",
            rank: 1,
            title: "종성 오류",
            subtitle: "받침 소리가 부정확해요",
            practiceTitle: "ㅁ, ㅂ, ㅍ, ㅃ 받침의 발음",
            guideText: "마지막에 입을 닫고 멈추는 것이 중요해요.\n입술 또는 혀를 붙이고 끊어주세요.",
            accentColor: Color(hex: "#FFA0A0"),
            imageName: "error_img_1"
        ),
        PronunciationDifficultyItem(
            id: "fortis-lenis-aspirated",
            rank: 2,
            title: "된소리/평음/격음 혼동",
            subtitle: "ㄱ/ㄲ/ㅋ 발음 구분이 어려워요",
            practiceTitle: "ㄱ, ㄲ, ㅋ 소리의 힘 조절",
            guideText: "소리를 시작할 때 목과 입안의 긴장감을 다르게 느껴보세요.\n짧은 단어부터 천천히 비교해보면 좋아요.",
            accentColor: Color(hex: "#FFF79E"),
            imageName: "error_img_1"
        ),
        PronunciationDifficultyItem(
            id: "syllable-simplification",
            rank: 3,
            title: "음절 구조 단순화",
            subtitle: "발음하지 않는 음절이 있어요",
            practiceTitle: "빠뜨린 음절 다시 짚기",
            guideText: "단어를 한 글자씩 나누어 읽고, 마지막에 자연스럽게 이어 말해보세요.\n박자를 맞추면 누락되는 소리를 줄일 수 있어요.",
            accentColor: Color(hex: "#B2B8FF"),
            imageName: "error_img_1"
        )
    ]
}

private struct PronunciationDonutChart: View {
    let score: Int
    let progressColor: Color
    @State private var animatedProgress = 0.0

    private var progress: Double {
        min(max(Double(score) / 100, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray9, lineWidth: 14)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            Text("\(score)점")
                .font(.Pretendard.SemiBold.size22)
                .foregroundColor(.white)
        }
        .onAppear {
            animatedProgress = 0

            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score) { _ in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
    }
}

private struct PronunciationDifficultyRow: View {
    let item: PronunciationDifficultyItem
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    rankBadge

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.Pretendard.SemiBold.size16)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(item.subtitle)
                            .font(.Pretendard.Medium.size12)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.gray6)
                        .frame(width: 24, height: 24)
                        .background(Color.gray8)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 8)
                .frame(minHeight: 68)

                if isExpanded {
                    VStack(spacing: 18) {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 148, height: 148)

                        VStack(spacing: 18) {
                            Text(item.practiceTitle)
                                .font(.Pretendard.SemiBold.size16)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(item.guideText)
                                .font(.Pretendard.Medium.size16)
                                .foregroundColor(.white)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 0)
            .background(Color(hex: "#1D1E26"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var rankBadge: some View {
        Text("\(item.rank)위")
            .font(.Pretendard.Medium.size14)
            .foregroundColor(item.accentColor)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(item.accentColor.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        AnalysisSummaryView(
            recording: Recording(
                fileURL: URL(fileURLWithPath: "/tmp/preview.wav"),
                createdAt: Date(),
                duration: 32
            )
        )
    }
}
