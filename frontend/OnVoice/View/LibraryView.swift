//
//  LibraryView.swift
//  OnVoice
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var recorder: AudioRecorder
    @Binding var selectedTab: OnVoiceTab
    @Binding var userProfile: UserProfile
    let onLogout: () -> Void
    let onWithdrawal: () -> Void
    @State private var isShowingSituationRecognition = false
    @State private var isShowingMyPage = false
    @State private var isShowingBulkDeleteAlert = false
    @State private var isSelectionMode = false
    @State private var selectedRecordingIDs: Set<Recording.ID> = []
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

    private var libraryRecordings: [Recording] {
        sections.flatMap { section in
            section.items.map(\.recording)
        }
    }

    private var selectedRecordings: [Recording] {
        libraryRecordings.filter { selectedRecordingIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeHeaderView(
                        title: "라이브러리",
                        userProfile: userProfile,
                        showsProfileButton: true,
                        titleTopOffset: 32,
                        onProfileButtonTap: {
                            isShowingMyPage = true
                        },
                        onTitleTrailingButtonTap: {
                            closeOpenedRowIfNeeded()
                            handleLibraryOptionsTap()
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
            .navigationDestination(isPresented: $isShowingMyPage) {
                MyPageView(
                    userProfile: $userProfile,
                    onLogout: onLogout,
                    onWithdrawal: onWithdrawal
                )
            }
            .navigationDestination(item: $selectedRecording) { recording in
                AnalysisSummaryView(recording: recording)
            }
            .onChange(of: selectedTab) { _ in
                closeOpenedRowIfNeeded()
                exitSelectionMode()
            }
            .onChange(of: isShowingSituationRecognition) { isPresented in
                if isPresented {
                    closeOpenedRowIfNeeded()
                    exitSelectionMode()
                }
            }
            .onChange(of: selectedRecording) { _ in
                closeOpenedRowIfNeeded()
            }
            .onChange(of: recorder.recordings) { _ in
                reconcileSelectedRecordings()
            }
            .alert("선택한 녹음", isPresented: $isShowingBulkDeleteAlert) {
                Button("취소", role: .cancel) {
                    isShowingBulkDeleteAlert = false
                    exitSelectionMode()
                }

                Button("삭제", role: .destructive) {
                    commitBulkDelete()
                }
            } message: {
                Text("선택한 \(selectedRecordingIDs.count)개의 녹음을 삭제할까요?")
            }
            .alert("녹음 이름 수정", isPresented: renameAlertIsPresented) {
                TextField("녹음 이름", text: limitedPendingRecordingTitle)

                Button("취소", role: .cancel) {
                    clearRenameState()
                }

                Button("저장") {
                    commitRename()
                }
            } message: {
                Text("녹음 이름은 최대 16자까지 입력할 수 있어요.")
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
            isSelectionMode: isSelectionMode,
            isSelected: selectedRecordingIDs.contains(item.recording.id),
            onTap: {
                if isSelectionMode {
                    toggleSelection(for: item.recording)
                } else {
                    selectedRecording = item.recording
                }
            },
            onEdit: {
                beginRenaming(item.recording, suggestedTitle: displayTitle)
            },
            onDelete: {
                clearRenameState()
                recordingToDelete = item.recording
                deletePromptTitle = displayTitle
            },
            onSelectionToggle: {
                toggleSelection(for: item.recording)
            }
        )
    }

    private func handleLibraryOptionsTap() {
        if !isSelectionMode {
            enterSelectionMode()
        } else if selectedRecordingIDs.isEmpty {
            exitSelectionMode()
        } else {
            isShowingBulkDeleteAlert = true
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

    private var limitedPendingRecordingTitle: Binding<String> {
        Binding(
            get: { pendingRecordingTitle },
            set: { pendingRecordingTitle = AudioRecorder.limitedRecordingTitle($0) }
        )
    }

    private func beginRenaming(_ recording: Recording, suggestedTitle: String) {
        exitSelectionMode()
        recordingToDelete = nil
        deletePromptTitle = ""
        recordingToRename = recording
        originalPendingRecordingTitle = suggestedTitle
        pendingRecordingTitle = AudioRecorder.limitedRecordingTitle(suggestedTitle)
    }

    private func clearRenameState() {
        recordingToRename = nil
        originalPendingRecordingTitle = ""
        pendingRecordingTitle = ""
    }

    private func commitRename() {
        guard let recordingToRename else { return }

        let sanitizedPendingTitle = AudioRecorder.sanitizedRecordingTitle(from: pendingRecordingTitle)
        let sanitizedCurrentTitle = AudioRecorder.sanitizedRecordingTitle(from: recordingToRename.title)
        let sanitizedOriginalDisplayTitle = AudioRecorder.sanitizedRecordingTitle(from: originalPendingRecordingTitle)

        if sanitizedPendingTitle == sanitizedCurrentTitle ||
            (recordingToRename.usesGeneratedDefaultTitle && sanitizedPendingTitle == sanitizedOriginalDisplayTitle) {
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

    private func enterSelectionMode() {
        guard !libraryRecordings.isEmpty else { return }

        clearRenameState()
        selectedRecording = nil
        recordingToDelete = nil
        deletePromptTitle = ""
        selectedRecordingIDs.removeAll()
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedRecordingIDs.removeAll()
    }

    private func toggleSelection(for recording: Recording) {
        if selectedRecordingIDs.contains(recording.id) {
            selectedRecordingIDs.remove(recording.id)
        } else {
            selectedRecordingIDs.insert(recording.id)
        }
    }

    private func reconcileSelectedRecordings() {
        let currentIDs = Set(libraryRecordings.map(\.id))
        selectedRecordingIDs = RecordingSelectionBehavior.reconciledSelectedIDs(
            selectedRecordingIDs,
            availableIDs: currentIDs
        )

        if RecordingSelectionBehavior.shouldExitSelectionMode(availableIDs: currentIDs) {
            exitSelectionMode()
        }
    }

    private func commitBulkDelete() {
        let recordingsToDelete = selectedRecordings
        var remainingSelectedIDs = selectedRecordingIDs

        do {
            for recording in recordingsToDelete {
                try recorder.deleteRecording(recording)
                remainingSelectedIDs.remove(recording.id)

                if selectedRecording?.id == recording.id {
                    selectedRecording = nil
                }
            }

            isShowingBulkDeleteAlert = false
            exitSelectionMode()
        } catch {
            let currentIDs = Set(libraryRecordings.map(\.id))
            selectedRecordingIDs = RecordingSelectionBehavior.reconciledSelectedIDs(
                remainingSelectedIDs,
                availableIDs: currentIDs
            )
            isShowingBulkDeleteAlert = false
            isSelectionMode = !selectedRecordingIDs.isEmpty
            presentMutationError(error)
        }
    }

    private func presentMutationError(_ error: Error) {
        mutationErrorMessage = error.localizedDescription
    }
}

#Preview {
    LibraryView(
        selectedTab: .constant(.library),
        userProfile: .constant(.placeholder),
        onLogout: {},
        onWithdrawal: {}
    )
        .environmentObject(AudioRecorder())
}
