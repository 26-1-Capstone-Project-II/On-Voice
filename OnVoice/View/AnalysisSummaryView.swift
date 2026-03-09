//
//  AnalysisSummaryView.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//


import SwiftUI

struct AnalysisSummaryView: View {
    let recording: Recording
    @StateObject private var recognizer = SpeechRecognition()
    @State private var isLoading = true
    @State private var goToPractice = false
    
    var body: some View {
        NavigationStack{
            ZStack {
                Color.suBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer().frame(height: 192)
                    
                    // 도넛 차트 + 점수
                    ChartView(
                        progress: recognizer.overallAccuracy,
                        scoreText: String(Int((recognizer.overallAccuracy * 100).rounded())),
                        label: "정확도"
                    )
                    
                    VStack(spacing: 8) {
                        Text("전체 문장 대비 정확 발음 비율")
                            .font(.Pretendard.Medium.size16)
                            .foregroundColor(.suGray2)
                        Text("표준 발음 vs 나의 발음")
                            .font(.Pretendard.Regular.size14)
                            .foregroundColor(.suGray4)
                    }
                    
                    Spacer()
                    
                    // 발음 오류 문장이 있을 때만 다음 버튼 표시
                    if !recognizer.errorSentences.isEmpty {
                        // 다음 버튼
                        NavigationLink(isActive: $goToPractice) {
                            RecordingAnalysisView(recording: recording)
                        } label: {
                            EmptyView()
                        }
                        
                        Button {
                            goToPractice = true
                        } label: {
                            Text("다음")
                                .font(.Pretendard.SemiBold.size20)
                                .foregroundColor(.suGray1)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Color.point)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 18)
                        }
                        .padding(.bottom, 24)
                    } else {
                        // 발음 오류가 없을 때 표시할 메시지
                        VStack(spacing: 16) {
                            Text("발음 오류가 발견되지 않았어요!")
                                .font(.Pretendard.Bold.size20)
                                .foregroundColor(.point)
                            
                            Text("모든 문장을 정확하게 발음했습니다")
                                .font(.Pretendard.Medium.size16)
                                .foregroundColor(.suGray2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 24)
                    }
                }
                .opacity(isLoading ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: isLoading)
                
                if isLoading {
                    ProgressView("분석 중…")
                        .progressViewStyle(.circular)
                        .foregroundStyle(.white)
                }
            }
            //네비게이션 타이틀
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("발음정확도평가")
                        .font(.Pretendard.Medium.size18)
                        .foregroundStyle(Color.suGray2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // 배경/스킴(글자 대비) 조정
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.suBlack, for: .navigationBar)
            // 아이콘/백버튼 대비 확보
            
            .task {
                await recognizer.analyze(url: recording.fileURL, referenceText: nil)
                isLoading = false
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}
