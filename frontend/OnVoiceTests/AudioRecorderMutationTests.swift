import XCTest
@testable import OnVoice

final class AudioRecorderMutationTests: XCTestCase {
    private var tempDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testRenameRecordingRejectsBlankTitle() throws {
        let recorder = AudioRecorder()
        let recording = try makeRecording(named: "기존 제목")
        recorder.recordings = [recording]

        XCTAssertThrowsError(try recorder.renameRecording(recording, to: "   \n  ")) { error in
            guard case AudioRecorder.RecordingMutationError.invalidTitle = error else {
                return XCTFail("Expected invalidTitle, got \(error)")
            }
        }
    }

    func testRenameRecordingReturnsOriginalWhenSanitizedTitleMatchesCurrentTitle() throws {
        let recorder = AudioRecorder()
        let recording = try makeRecording(named: "회의 메모")
        recorder.recordings = [recording]

        let updatedRecording = try recorder.renameRecording(recording, to: "  회의 메모  ")

        XCTAssertEqual(updatedRecording, recording)
        XCTAssertEqual(recorder.recordings, [recording])
        XCTAssertTrue(FileManager.default.fileExists(atPath: recording.fileURL.path))
    }

    func testRenameRecordingMovesFileAndUpdatesPublishedRecordings() throws {
        let recorder = AudioRecorder()
        let recording = try makeRecording(named: "기존 제목")
        recorder.recordings = [recording]

        let updatedRecording = try recorder.renameRecording(recording, to: "  새 제목  ")

        XCTAssertEqual(updatedRecording.title, "새 제목")
        XCTAssertEqual(recorder.recordings, [updatedRecording])
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: updatedRecording.fileURL.path))
    }

    func testDeleteRecordingRemovesFileAndRecording() throws {
        let recorder = AudioRecorder()
        let recording = try makeRecording(named: "삭제 대상")
        recorder.recordings = [recording]

        try recorder.deleteRecording(recording)

        XCTAssertTrue(recorder.recordings.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recording.fileURL.path))
    }

    func testInitializesWithPersistedWavRecordings() throws {
        let olderURL = try makePersistedFile(named: "Recording_20260414_090000", extension: "wav")
        let newerURL = try makePersistedFile(named: "Recording_20260415_090000", extension: "wav")
        _ = try makePersistedFile(named: "audio", extension: "m4a")

        let recorder = AudioRecorder(recordingsDirectoryURL: tempDirectoryURL)

        XCTAssertEqual(recorder.recordings.map(\.fileURL), [newerURL, olderURL])
        XCTAssertEqual(recorder.recordings.map(\.title), [
            "Recording_20260415_090000",
            "Recording_20260414_090000"
        ])
    }

    func testInitializesWithRenamedPersistedWavRecordingUsingFileCreationDate() throws {
        let creationDate = Date(timeIntervalSince1970: 1_800)
        let fileURL = try makePersistedFile(named: "회의 메모", extension: "wav")
        try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: fileURL.path)

        let recorder = AudioRecorder(recordingsDirectoryURL: tempDirectoryURL)

        XCTAssertEqual(recorder.recordings.count, 1)
        XCTAssertEqual(recorder.recordings[0].fileURL, fileURL)
        XCTAssertEqual(recorder.recordings[0].createdAt, creationDate)
    }

    private func makeRecording(named name: String) throws -> Recording {
        let fileURL = tempDirectoryURL
            .appendingPathComponent(name)
            .appendingPathExtension("m4a")
        let created = FileManager.default.createFile(atPath: fileURL.path, contents: Data())
        XCTAssertTrue(created)

        return Recording(
            fileURL: fileURL,
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 42
        )
    }

    private func makePersistedFile(named name: String, extension fileExtension: String) throws -> URL {
        let fileURL = tempDirectoryURL
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
        let created = FileManager.default.createFile(atPath: fileURL.path, contents: Data())
        XCTAssertTrue(created)
        return fileURL
    }
}
