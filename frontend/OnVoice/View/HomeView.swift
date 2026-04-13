//
//  HomeView.swift
//  OnVoice
//
//  Created by Lee YunJi on 7/25/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var recorder: AudioRecorder
    @Binding var selectedTab: OnVoiceTab
    @State private var isShowingSituationRecognition = false
    @State private var selectedRecording: Recording?
    @State private var openedRowID: Recording.ID?

    private var displayedRecordings: [(index: Int, recording: Recording)] {
        Array(recorder.recordings.reversed().enumerated()).map { offset, recording in
            (recorder.recordings.count - offset, recording)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeHeaderView(
                        title: todayDateString(),
                        showsProfileButton: true
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("기록")
                            .onVoiceTextStyle(.body2, color: .sub)
                            .padding(.top, 18)
                        GeometryReader { proxy in
                            if displayedRecordings.isEmpty {
                                ScrollView(showsIndicators: false) {
                                    EmptyRecordView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 88)
                                        .padding(.bottom, 132)
                                        .frame(minHeight: proxy.size.height, alignment: .top)
                                }
                                .scrollBounceBehavior(.basedOnSize)
                                .padding(.top, 18)
                            } else {
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 16) {
                                        ForEach(displayedRecordings, id: \.recording.id) { item in
                                            RecordingRowView(
                                                id: item.recording.id,
                                                title: "새로운 대화 기록 (\(item.index))",
                                                subtitle: "\(item.recording.formattedDate) • \(item.recording.formattedDuration)",
                                                openedRowID: $openedRowID,
                                                onTap: {
                                                    selectedRecording = item.recording
                                                }
                                            )
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.bottom, 132)
                                }
                                .padding(.top, 18)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomDockView(
                    selectedTab: $selectedTab,
                    onAddTap: { isShowingSituationRecognition = true }
                )
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSituationRecognition) {
                SituationRecognitionView()
            }
            .navigationDestination(item: $selectedRecording) { recording in
                AnalysisSummaryView(recording: recording)
            }
            .onAppear {
                resetSwipeState()
            }
            .onDisappear {
                resetSwipeState()
            }
            .onChange(of: selectedTab) { _ in
                resetSwipeState()
            }
            .onChange(of: isShowingSituationRecognition) { isPresented in
                if isPresented {
                    resetSwipeState()
                }
            }
            .onChange(of: selectedRecording) { recording in
                if recording != nil {
                    resetSwipeState()
                }
            }
        }
    }

    private func resetSwipeState() {
        openedRowID = nil
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년\nM월 d일 EEEE"
        return formatter.string(from: Date())
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(AudioRecorder())
}
