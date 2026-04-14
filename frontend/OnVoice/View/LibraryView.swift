//
//  LibraryView.swift
//  OnVoice
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var recorder: AudioRecorder
    @Binding var selectedTab: OnVoiceTab
    @State private var isShowingSituationRecognition = false
    @State private var isShowingLibraryOptionsAlert = false
    @State private var selectedRecording: Recording?
    @State private var openedRowID: Recording.ID?
    @State private var recordingToRename: Recording?
    @State private var originalPendingRecordingTitle = ""
    @State private var pendingRecordingTitle = ""
    @State private var recordingToDelete: Recording?
    @State private var deletePromptTitle = ""
    @State private var mutationErrorMessage = ""

    private var sections: [RecordingLibrarySection] {
        RecordingListOrganizer.librarySections(from: recorder.recordings)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeHeaderView(
                        title: "라이브러리",
                        showsProfileButton: true,
                        titleTopOffset: 32,
                        onTitleTrailingButtonTap: {
                            isShowingLibraryOptionsAlert = true
                        }
                    )

                    libraryContent
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
            .alert("준비 중", isPresented: $isShowingLibraryOptionsAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("라이브러리 추가 옵션은 다음 단계에서 연결할 예정입니다.")
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
                Text("녹음 파일 이름을 바꾸면 라이브러리 리스트 제목도 함께 변경됩니다.")
            }
            .alert("녹음 삭제", isPresented: deleteAlertIsPresented, presenting: recordingToDelete) { recording in
                Button("취소", role: .cancel) {
                    recordingToDelete = nil
                    deletePromptTitle = ""
                }

                Button("삭제", role: .destructive) {
                    commitDelete(recording)
                }
            } message: { _ in
                Text("'\(deletePromptTitle)' 녹음을 삭제할까요?")
            }
            .alert("작업 실패", isPresented: mutationErrorIsPresented) {
                Button("확인", role: .cancel) {
                    mutationErrorMessage = ""
                }
            } message: {
                Text(mutationErrorMessage)
            }
        }
    }

    private var libraryContent: some View {
        Group {
            if sections.isEmpty {
                emptyLibraryContent
            } else {
                recordingsLibraryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyLibraryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("기록")
                .onVoiceTextStyle(.body2, color: .sub)
                .padding(.top, 18)
                .hidden()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    EmptyRecordView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 88)
                        .padding(.bottom, 132)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 18)
    }

    private var recordingsLibraryContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                ForEach(sections) { section in
                    librarySection(section)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 132)
        }
        .padding(.horizontal, 18)
    }

    private func librarySection(_ section: RecordingLibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title)
                .onVoiceTextStyle(.title2, color: .gray1)

            VStack(spacing: 16) {
                ForEach(section.items) { item in
                    libraryRow(item)
                }
            }
        }
    }

    private func libraryRow(_ item: RecordingDisplayItem) -> some View {
        let displayTitle = RecordingListOrganizer.displayTitle(for: item)

        return RecordingRowView(
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
                clearRenameState()
                recordingToDelete = item.recording
                deletePromptTitle = displayTitle
            }
        )
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

    private var mutationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { !mutationErrorMessage.isEmpty },
            set: { isPresented in
                if !isPresented {
                    mutationErrorMessage = ""
                }
            }
        )
    }

    private func beginRenaming(_ recording: Recording, suggestedTitle: String) {
        recordingToDelete = nil
        deletePromptTitle = ""
        recordingToRename = recording
        originalPendingRecordingTitle = suggestedTitle
        pendingRecordingTitle = suggestedTitle
    }

    private func clearRenameState() {
        recordingToRename = nil
        originalPendingRecordingTitle = ""
        pendingRecordingTitle = ""
    }

    private func commitRename() {
        guard let recordingToRename else { return }

        if recordingToRename.usesGeneratedDefaultTitle,
           pendingRecordingTitle == originalPendingRecordingTitle {
            clearRenameState()
            return
        }

        do {
            let updatedRecording = try recorder.renameRecording(recordingToRename, to: pendingRecordingTitle)
            if selectedRecording?.id == recordingToRename.id {
                selectedRecording = updatedRecording
            }
            clearRenameState()
        } catch {
            clearRenameState()
            presentMutationError(error)
        }
    }

    private func commitDelete(_ recording: Recording) {
        do {
            try recorder.deleteRecording(recording)
            if selectedRecording?.id == recording.id {
                selectedRecording = nil
            }
            recordingToDelete = nil
            deletePromptTitle = ""
        } catch {
            recordingToDelete = nil
            deletePromptTitle = ""
            presentMutationError(error)
        }
    }

    private func presentMutationError(_ error: Error) {
        mutationErrorMessage = error.localizedDescription
    }
}

#Preview {
    LibraryView(selectedTab: .constant(.library))
        .environmentObject(AudioRecorder())
}
