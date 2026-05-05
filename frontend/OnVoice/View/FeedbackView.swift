//
//  FeedbackView.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/23/25.
//

import SwiftUI

struct FeedbackView: View {
    private let guideSheetHiddenOffset: CGFloat = 420
    private let guideSheetDismissThreshold: CGFloat = 120
    private let guideSheetDimOpacity: Double = 0.50

    private var guideSheetAnimation: Animation {
        .easeInOut(duration: 0.32)
    }
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var recorder: AudioRecorder
    @ObservedObject private var sessionController = RecordingSessionController.shared
    @AppStorage("shouldSkipVoicePitchGuide") private var shouldSkipVoicePitchGuide = false
    @State private var isPaused = false
    @State private var isGuideSheetPresented = false
    @State private var isGuideSheetVisible = false
    @State private var isGuideSheetDismissing = false
    @State private var guideSheetDragOffset: CGFloat = 0
    @State private var hasPresentedGuideOnAppear = false
    
    @State private var noiseMeter = NoiseMeter.shared
    
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
                        .disabled(isGuideSheetPresented)
                        .opacity(isGuideSheetPresented ? 0.35 : 1)
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
                                await terminateSessionAndDismiss()
                            }
                        } label: {
                            Text("종료")
                                .font(.Pretendard.Regular.size17)
                                .kerning(-0.43)
                                .foregroundColor(.main)
                        }
                        .disabled(isGuideSheetPresented)
                        .opacity(isGuideSheetPresented ? 0.35 : 1)
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
            .onChange(of: isGuideSheetPresented) { _, isPresented in
                guard isPresented, !isGuideSheetVisible else { return }

                withAnimation(guideSheetAnimation) {
                    guideSheetDragOffset = 0
                    isGuideSheetVisible = true
                }
            }
            .onDisappear {
                isGuideSheetPresented = false
                isGuideSheetVisible = false
                currentSituation = nil
            }
            .onChange(of: sessionController.terminationCount) { _, _ in
                dismiss()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    @MainActor
    private func terminateSessionAndDismiss() async {
        await sessionController.terminateActiveSession()
        dismiss()
    }

    private var guideSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(isGuideSheetVisible ? guideSheetDimOpacity : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissGuideSheet()
                }

            VoicePitchGuideBottomSheet {
                dismissGuideSheet()
            }
            .offset(y: sheetOffset)
            .gesture(guideSheetDragGesture)
        }
        .allowsHitTesting(isGuideSheetPresented)
    }

    private func presentGuideSheet() {
        guard !isGuideSheetDismissing else { return }

        guard !isGuideSheetPresented else {
            if !isGuideSheetVisible {
                withAnimation(guideSheetAnimation) {
                    isGuideSheetVisible = true
                }
            }
            return
        }

        guideSheetDragOffset = 0
        isGuideSheetVisible = false
        isGuideSheetPresented = true
    }

    private func dismissGuideSheet() {
        guard isGuideSheetPresented, !isGuideSheetDismissing else { return }

        isGuideSheetDismissing = true

        withAnimation(
            guideSheetAnimation,
            completionCriteria: .logicallyComplete
        ) {
            guideSheetDragOffset = 0
            isGuideSheetVisible = false
        } completion: {
            isGuideSheetPresented = false
            isGuideSheetDismissing = false
        }
    }

    private var sheetOffset: CGFloat {
        (isGuideSheetVisible ? 0 : guideSheetHiddenOffset) + guideSheetDragOffset
    }

    private var guideSheetDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isGuideSheetDismissing else { return }
                guideSheetDragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                guard !isGuideSheetDismissing else { return }

                if value.translation.height >= guideSheetDismissThreshold {
                    dismissGuideSheet()
                } else {
                    withAnimation(guideSheetAnimation) {
                        guideSheetDragOffset = 0
                    }
                }
            }
    }
}

//#Preview {
//    FeedbackView(
//        currentSituation: .constant(Situation.quietTalking)
//    )
//}
