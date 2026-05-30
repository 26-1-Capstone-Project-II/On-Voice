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

    /// 점수 카드 본문 코멘트. 분석 결과의 summaryComment(generator 가 1위 카테고리
    /// 또는 등급 fallback 으로 채운 값)를 우선 사용하고, 전사 실패 등으로 비어 있을
    /// 때만 화면이 직접 등급 기반 fallback 을 호출한다. 과거 여기 박혀 있던 "받침..."
    /// 하드코딩 문구는 제거하고 PronunciationSummaryCommentGenerator 로 일원화했다.
    private var summaryComment: String {
        if let comment = viewModel.analysis?.summaryComment, !comment.isEmpty {
            return comment
        }
        return PronunciationSummaryCommentGenerator.fallback(for: scoreLevel)
    }

    /// 분석 결과의 10종 raw 카테고리에서 빈도 상위 3개를 그대로 노출.
    /// 분석 전(viewModel.analysis == nil) 이거나 오류가 한 건도 없을 때는 빈 배열을
    /// 돌려주고, difficultySection 자체가 숨겨진다.
    private var difficultyItems: [PronunciationDifficultyResult] {
        viewModel.analysis?.difficultyItems ?? []
    }

    /// 분석 결과가 아직 도착하지 않은 로딩 상태. 이때 scoreSection/summaryComment 는
    /// fallback(54점·고정 코멘트)을 돌려주므로, 로딩 화면 뒤에 이 하드코딩 UI 가
    /// 비치지 않도록 본문 대신 loadingView 만 노출한다.
    private var isAnalyzing: Bool {
        viewModel.isLoading && viewModel.analysis == nil
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            if isAnalyzing {
                loadingView
            } else {
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)

            VStack(spacing: 8) {
                Text("발음을 분석하고 있어요")
                    .font(.Pretendard.SemiBold.size18)
                    .foregroundColor(.white)

                Text("잠시만 기다려 주세요")
                    .font(.Pretendard.Medium.size14)
                    .foregroundColor(.gray3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                    Text(summaryComment)
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

    @ViewBuilder
    private var difficultySection: some View {
        if !difficultyItems.isEmpty {
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

// PronunciationScoreLevel 과 "내가 어려워하는 발음" 카드 데이터는 모두
// Model/AnalysisSummary.swift 의 PronunciationDifficultyResult 로 통합됨.
// 카드 데이터는 SpeechAnalysisService 가 PronunciationDifficultyAggregator 로
// 산출해 AnalysisResult.difficultyItems 에 채운다.

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
    let item: PronunciationDifficultyResult
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
