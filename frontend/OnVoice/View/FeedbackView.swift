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
    @AppStorage("shouldSkipVoicePitchGuide") private var shouldSkipVoicePitchGuide = false
    @State private var isPaused = false
<<<<<<< HEAD
    @State private var isGuideSheetPresented = false
    @State private var isGuideSheetVisible = false
    @State private var isGuideSheetDismissing = false
    @State private var guideSheetDragOffset: CGFloat = 0
=======
    @State private var guideSheetState = VoicePitchGuideSheetState()
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
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
<<<<<<< HEAD
                            presentGuideSheet()
=======
                            presentGuideSheet(source: .manual)
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
                        } label: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.main)
                        }
<<<<<<< HEAD
                        .disabled(isGuideSheetPresented)
                        .opacity(isGuideSheetPresented ? 0.35 : 1)
=======
                        .disabled(guideSheetState.isPresented)
                        .opacity(guideSheetState.isPresented ? 0.35 : 1)
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
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
<<<<<<< HEAD
                        .disabled(isGuideSheetPresented)
                        .opacity(isGuideSheetPresented ? 0.35 : 1)
                    }
                }

                if isGuideSheetPresented {
=======
                        .disabled(guideSheetState.isPresented)
                        .opacity(guideSheetState.isPresented ? 0.35 : 1)
                    }
                }

                if guideSheetState.isPresented {
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
                    guideSheetOverlay
                        .zIndex(1)
                }
            }
            .onAppear { // FeedBackView 시작 시 소리 측정 시작
                if !hasPresentedGuideOnAppear {
                    hasPresentedGuideOnAppear = true
<<<<<<< HEAD
                    presentGuideSheet()
=======
                    if VoicePitchGuideSheetState.shouldAutoPresent(
                        skipPreference: shouldSkipVoicePitchGuide
                    ) {
                        presentGuideSheet(source: .automatic)
                    }
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
                }
                recorder.start()
                Task {
                    noiseMeter.nowSituation = currentSituation // 사용자가 선택한 상황 LiveActivity에 전달
                    await noiseMeter.measure()
                    noiseMeter.startLiveActivity()
                }
            }
<<<<<<< HEAD
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
=======
            .onChange(of: guideSheetState.isPresented) { _, isPresented in
                guard isPresented, !guideSheetState.isVisible else { return }

                withAnimation(guideSheetAnimation) {
                    guideSheetState.resetDragOffset()
                    guideSheetState.reveal()
                }
            }
            .onDisappear {
                guideSheetState = VoicePitchGuideSheetState()
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
                currentSituation = nil
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var guideSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black
<<<<<<< HEAD
                .opacity(isGuideSheetVisible ? guideSheetDimOpacity : 0)
=======
                .opacity(guideSheetState.isVisible ? guideSheetDimOpacity : 0)
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissGuideSheet()
                }

<<<<<<< HEAD
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
=======
            ZStack(alignment: .topTrailing) {
                VoicePitchGuideBottomSheet(
                    onConfirm: {
                        dismissGuideSheet()
                    },
                    onDragChanged: { value in
                        handleGuideSheetDragChanged(value)
                    },
                    onDragEnded: { value in
                        handleGuideSheetDragEnded(value)
                    }
                )

                if guideSheetState.source.showsDoNotShowAgainButton {
                    Button {
                        handleDoNotShowAgain()
                    } label: {
                        Text("다시 보지 않기")
                            .font(.Pretendard.Regular.size14)
                            .kerning(-0.3)
                            .foregroundStyle(Color.suGray4)
                            .frame(width: 120, height: 38, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 58)
                    .padding(.trailing, 24)
                    .zIndex(10)
                }
            }
            .offset(y: sheetOffset)
        }
        .allowsHitTesting(guideSheetState.isPresented)
    }

    private func presentGuideSheet(source: VoicePitchGuideSheetPresentationSource) {
        switch guideSheetState.prepareForPresentation(source: source) {
        case .blocked, .alreadyVisible:
            return
        case .insertedHidden:
            return
        case .revealExistingSheet:
            withAnimation(guideSheetAnimation) {
                guideSheetState.reveal()
            }
        }
    }

    private func dismissGuideSheet() {
        guard guideSheetState.beginDismissal() else { return }
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08

        withAnimation(
            guideSheetAnimation,
            completionCriteria: .logicallyComplete
        ) {
<<<<<<< HEAD
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
=======
            guideSheetState.prepareForDismissalAnimation()
        } completion: {
            guideSheetState.completeDismissal()
        }
    }

    private func handleDoNotShowAgain() {
        shouldSkipVoicePitchGuide = true
        dismissGuideSheet()
    }

    private var sheetOffset: CGFloat {
        (guideSheetState.isVisible ? 0 : guideSheetHiddenOffset) + guideSheetState.dragOffset
    }

    private func handleGuideSheetDragChanged(_ value: DragGesture.Value) {
        guideSheetState.updateDragOffset(with: value.translation.height)
    }

    private func handleGuideSheetDragEnded(_ value: DragGesture.Value) {
        guard !guideSheetState.isDismissing else { return }

        if VoicePitchGuideSheetState.shouldDismiss(
            for: value.translation.height,
            threshold: guideSheetDismissThreshold
        ) {
            dismissGuideSheet()
        } else {
            withAnimation(guideSheetAnimation) {
                guideSheetState.resetDragOffset()
            }
        }
>>>>>>> e680b062158768dac31aa0a1bc45c64082202a08
    }
}

//#Preview {
//    FeedbackView(
//        currentSituation: .constant(Situation.quietTalking)
//    )
//}
