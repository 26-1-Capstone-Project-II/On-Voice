import CoreGraphics
import XCTest
@testable import OnVoice

final class RecordingRowSwipeBehaviorTests: XCTestCase {
    private let rowID = URL(fileURLWithPath: "/tmp/row.m4a")
    private let otherRowID = URL(fileURLWithPath: "/tmp/other-row.m4a")
    private let revealWidth: CGFloat = 148

    func testBaseOffsetUsesOpenedRowIDAsSingleSourceOfTruth() {
        XCTAssertEqual(
            RecordingRowSwipeBehavior.baseOffset(
                for: rowID,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            -revealWidth
        )

        XCTAssertEqual(
            RecordingRowSwipeBehavior.baseOffset(
                for: otherRowID,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            0
        )

        XCTAssertEqual(
            RecordingRowSwipeBehavior.baseOffset(
                for: nil,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            0
        )
    }

    func testClampedOffsetStaysWithinRevealWidth() {
        XCTAssertEqual(
            RecordingRowSwipeBehavior.clampedOffset(
                baseOffset: 0,
                translation: -220,
                revealWidth: revealWidth
            ),
            -revealWidth
        )

        XCTAssertEqual(
            RecordingRowSwipeBehavior.clampedOffset(
                baseOffset: -revealWidth,
                translation: 220,
                revealWidth: revealWidth
            ),
            0
        )
    }

    func testResolvedOpenedRowIDOpensOnlyPastHalfThreshold() {
        XCTAssertEqual(
            RecordingRowSwipeBehavior.resolvedOpenedRowID(
                for: -90,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            rowID
        )

        XCTAssertNil(
            RecordingRowSwipeBehavior.resolvedOpenedRowID(
                for: -(revealWidth / 2),
                rowID: rowID,
                revealWidth: revealWidth
            )
        )
    }

    func testResolvedOpenedRowIDClosesWhenDragReturnsPastThreshold() {
        XCTAssertNil(
            RecordingRowSwipeBehavior.resolvedOpenedRowID(
                for: -40,
                rowID: rowID,
                revealWidth: revealWidth
            )
        )
    }

    func testDifferentOpenRowStillLetsNewRowComputeFromClosedBaseline() {
        let baseOffset = RecordingRowSwipeBehavior.baseOffset(
            for: otherRowID,
            rowID: rowID,
            revealWidth: revealWidth
        )
        let finalOffset = RecordingRowSwipeBehavior.clampedOffset(
            baseOffset: baseOffset,
            translation: -100,
            revealWidth: revealWidth
        )

        XCTAssertEqual(finalOffset, -100)
        XCTAssertEqual(
            RecordingRowSwipeBehavior.resolvedOpenedRowID(
                for: finalOffset,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            rowID
        )
    }

    func testRecordingListOrganizerSplitsHomeAndLibraryByRelativeDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 12))!
        let todayRecording = makeRecording(
            named: "Recording_20260414_090000",
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9))!
        )
        let previous7Recording = makeRecording(
            named: "Recording_20260410_090000",
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 9))!
        )
        let previous30Recording = makeRecording(
            named: "Recording_20260401_090000",
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9))!
        )
        let monthlyRecording = makeRecording(
            named: "Recording_20260220_090000",
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 9))!
        )

        let recordings = [monthlyRecording, previous30Recording, previous7Recording, todayRecording]

        let homeItems = withFixedCurrentDate(now) {
            RecordingListOrganizer.homeItems(from: recordings, calendar: calendar)
        }
        let librarySections = withFixedCurrentDate(now) {
            RecordingListOrganizer.librarySections(from: recordings, calendar: calendar)
        }

        XCTAssertEqual(homeItems.map(\.recording.id), [todayRecording.id])
        XCTAssertEqual(librarySections.map(\.title), ["이전 7일", "이전 30일", "2월"])
        XCTAssertEqual(librarySections[0].items.map(\.recording.id), [previous7Recording.id])
        XCTAssertEqual(librarySections[1].items.map(\.recording.id), [previous30Recording.id])
        XCTAssertEqual(librarySections[2].items.map(\.recording.id), [monthlyRecording.id])
    }

    private func makeRecording(named name: String, createdAt: Date) -> Recording {
        Recording(
            fileURL: URL(fileURLWithPath: "/tmp/\(name).m4a"),
            createdAt: createdAt,
            duration: 49
        )
    }

    private func withFixedCurrentDate<T>(_ date: Date, perform work: () -> T) -> T {
        let previousDateFactory = RecordingListOrganizer.currentDate
        RecordingListOrganizer.currentDate = { date }
        defer { RecordingListOrganizer.currentDate = previousDateFactory }
        return work()
    }
}
