//
//  FeedbackView.swift
//  SpeakUP
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI
import ActivityKit

struct FeedbackView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var recorder: AudioRecorder
    @State private var isPaused = false
    @State private var isInfoSheetPresented = false
    
    @State private var noiseMeter = NoiseMeter.shared
    @State private var activity: Activity<DynamicIslandWidgetAttributes>?
    
    // 선택한 상황에 따라서 currentIndex(0~3)에 맞춰서 데시벨 다르게
    @Binding var currentSituation: Situation? // 현재 선택한 상황
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.suBlack
                    .ignoresSafeArea()
                
                VoicePitchView(noiseMeter: $noiseMeter,
                               currentSituation: $currentSituation)
                .navigationBarBackButtonHidden()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            isInfoSheetPresented = true
                        } label: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.point)
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text(LocalizedStringResource(stringLiteral: currentSituation?.title ?? ""))
                            .font(.Pretendard.SemiBold.size17)
                            .kerning(-0.43)
                            .foregroundColor(.suGray4)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // 종료 버튼
                        Button {
                            Task {
                                recorder.stop()
                                await noiseMeter.endLiveActivity()
                            }
                            dismiss()
                        } label: {
                            Text("종료")
                                .font(.Pretendard.Regular.size17)
                                .kerning(-0.43)
                                .foregroundColor(.point)
                        }
                    }
                }
//                InfoSheetView(isShowing: $isInfoSheetPresented, nowSituation: $currentSituation)
            }
            .onAppear { // FeedBackView 시작 시 소리 측정 시작
                recorder.start()
                Task {
                    noiseMeter.nowSituation = currentSituation // 사용자가 선택한 상황 LiveActivity에 전달
                    await noiseMeter.measure()
                    noiseMeter.startLiveActivity()
                }
            }
            .onDisappear {
                currentSituation = nil
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

//#Preview {
//    FeedbackView(
//        currentSituation: .constant(Situation.quietTalking)
//    )
//}
