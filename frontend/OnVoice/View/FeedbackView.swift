//
//  FeedbackView.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI
import ActivityKit

struct FeedbackView: View {
    private let guideSheetAnimationDuration: Double = 0.32
    private var guideSheetAnimation: Animation {
        .easeInOut(duration: guideSheetAnimationDuration)
    }
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var recorder: AudioRecorder
    @State private var isPaused = false
    @State private var isGuideSheetPresented = false
    @State private var isGuideSheetVisible = false
    @State private var hasPresentedGuideOnAppear = false
    @State private var guideSheetTransitionTask: Task<Void, Never>?
    
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
                            presentGuideSheet()
                        } label: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.main)
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
                                .foregroundColor(.main)
                        }
                    }
                }

                if isGuideSheetPresented {
                    guideSheetOverlay
                        .zIndex(1)
                }
            }
            .onAppear { // FeedBackView 시작 시 소리 측정 시작
                if !hasPresentedGuideOnAppear {
                    hasPresentedGuideOnAppear = true
                    presentGuideSheet()
                }
                recorder.start()
                Task {
                    noiseMeter.nowSituation = currentSituation // 사용자가 선택한 상황 LiveActivity에 전달
                    await noiseMeter.measure()
                    noiseMeter.startLiveActivity()
                }
            }
            .onDisappear {
                guideSheetTransitionTask?.cancel()
                currentSituation = nil
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var guideSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(isGuideSheetVisible ? 0.28 : 0)
                .ignoresSafeArea()

            VoicePitchGuideBottomSheet {
                dismissGuideSheet()
            }
            .offset(y: isGuideSheetVisible ? 0 : 420)
        }
    }

    private func presentGuideSheet() {
        guideSheetTransitionTask?.cancel()

        guard !isGuideSheetPresented else {
            if !isGuideSheetVisible {
                withAnimation(guideSheetAnimation) {
                    isGuideSheetVisible = true
                }
            }
            return
        }

        isGuideSheetPresented = true

        guideSheetTransitionTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, isGuideSheetPresented else { return }

            withAnimation(guideSheetAnimation) {
                isGuideSheetVisible = true
            }
        }
    }

    private func dismissGuideSheet() {
        guideSheetTransitionTask?.cancel()

        withAnimation(guideSheetAnimation) {
            isGuideSheetVisible = false
        }

        guideSheetTransitionTask = Task { @MainActor in
            let duration = UInt64(guideSheetAnimationDuration * 1_000_000_000)

            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled, !isGuideSheetVisible else { return }

            isGuideSheetPresented = false
        }
    }
}

//#Preview {
//    FeedbackView(
//        currentSituation: .constant(Situation.quietTalking)
//    )
//}
