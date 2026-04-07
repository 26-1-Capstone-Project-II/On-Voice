//
//  HomeView.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/25/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var recorder: AudioRecorder
    @State private var isShowingSituationRecognition = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading){
                        Image("logo")
                            .padding(.top, 18)
                        Text(todayDateString())
                            .onVoiceTextStyle(.head1, color: .gray1)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("기록")
                            .onVoiceTextStyle(.body4, color: .gray2)
                            .padding(.top, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
        
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(recorder.recordings) { rec in
                                NavigationLink {
                                    AnalysisSummaryView(recording: rec)
                                } label: {
                                    HStack {
                                        Image(systemName: "microphone.circle.fill")
                                            .foregroundColor(.main)
                                            .padding(.leading, 12)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("새로운 대화 기록")
                                                .onVoiceTextStyle(.body4, color: .white)
                                            Text("\(rec.formattedDate)  \(rec.formattedDuration)")
                                                .font(.Pretendard.Regular.size14)
                                                .foregroundColor(.gray4)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray3)
                                            .padding(.trailing, 12)
                                    }
                                    .frame(height: 56)
                                    .background(Color.gray7)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 80)
                    }
                }
                
                // Floating '+' 버튼
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isShowingSituationRecognition = true
                        } label: {
                            Image(.append)
                        }
                        .padding(.bottom, 24)
                        .padding(.trailing, 24)
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingSituationRecognition) {
                SituationRecognitionView()
            }
        }
    }
    
    /// 오늘 날짜 "2025년 7월 24일 목요일" 형식 반환
    func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 \nM월 d일 EEEE"
        return formatter.string(from: Date())
    }
}
