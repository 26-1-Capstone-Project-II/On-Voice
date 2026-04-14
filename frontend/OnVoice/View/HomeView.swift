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
    @State private var recordingToRename: Recording?
    @State private var pendingRecordingTitle = ""
    @State private var recordingToDelete: Recording?
    @State private var deletePromptTitle = ""

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
                                            let displayTitle = title(for: item.recording, index: item.index)
                                            RecordingRowView(
                                                id: item.recording.id,
                                                title: displayTitle,
                                                subtitle: "\(item.recording.formattedDate) • \(item.recording.formattedDuration)",
                                                openedRowID: $openedRowID,
                                                onTap: {
                                                    selectedRecording = item.recording
                                                },
                                                onEdit: {
                                                    beginRenaming(item.recording, suggestedTitle: displayTitle)
                                                },
                                                onDelete: {
                                                    recordingToDelete = item.recording
                                                    deletePromptTitle = displayTitle
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
            .simultaneousGesture(
                TapGesture().onEnded {
                    closeOpenedRowIfNeeded()
                }
            )
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
            .onChange(of: selectedTab) { _ in
                closeOpenedRowIfNeeded()
            }
            .onChange(of: isShowingSituationRecognition) { isPresented in
                if isPresented {
                    closeOpenedRowIfNeeded()
                }
            }
            .onChange(of: selectedRecording) { _ in
                closeOpenedRowIfNeeded()
            }
            .alert("녹음 이름 수정", isPresented: renameAlertIsPresented) {
                TextField("녹음 이름", text: $pendingRecordingTitle)

                Button("취소", role: .cancel) {
                    clearRenameState()
                }

                Button("저장") {
                    commitRename()
                }
            } message: {
                Text("녹음 파일 이름을 바꾸면 홈 화면 리스트 제목도 함께 변경됩니다.")
            }
            .alert("녹음 삭제", isPresented: deleteAlertIsPresented, presenting: recordingToDelete) { recording in
                Button("취소", role: .cancel) {
                    recordingToDelete = nil
                    deletePromptTitle = ""
                }

                Button("삭제", role: .destructive) {
                    recorder.deleteRecording(recording)
                    recordingToDelete = nil
                    deletePromptTitle = ""
                }
            } message: { recording in
                Text("'\(deletePromptTitle)' 녹음을 삭제할까요?")
            }
        }
    }

    private func closeOpenedRowIfNeeded() {
        guard openedRowID != nil else { return }

        withAnimation(RecordingRowSwipeBehavior.snapAnimation) {
            openedRowID = nil
        }
    }

    private var renameAlertIsPresented: Binding<Bool> {
        Binding(
            get: { recordingToRename != nil },
            set: { isPresented in
                if !isPresented {
                    clearRenameState()
                }
            }
        )
    }

    private var deleteAlertIsPresented: Binding<Bool> {
        Binding(
            get: { recordingToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    recordingToDelete = nil
                    deletePromptTitle = ""
                }
            }
        )
    }

    private func beginRenaming(_ recording: Recording, suggestedTitle: String) {
        recordingToRename = recording
        pendingRecordingTitle = suggestedTitle
    }

    private func clearRenameState() {
        recordingToRename = nil
        pendingRecordingTitle = ""
    }

    private func commitRename() {
        guard let recordingToRename else { return }

        let updatedRecording = recorder.renameRecording(recordingToRename, to: pendingRecordingTitle)
        if let updatedRecording, selectedRecording?.id == recordingToRename.id {
            selectedRecording = updatedRecording
        }
        clearRenameState()
    }

    private func title(for recording: Recording, index: Int) -> String {
        if recording.title.hasPrefix("Recording_") {
            return "새로운 대화 기록 (\(index))"
        }

        return recording.title
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
