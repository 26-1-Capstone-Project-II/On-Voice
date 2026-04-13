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

    func testTargetOpenedRowIDOpensOnlyPastHalfThreshold() {
        XCTAssertEqual(
            RecordingRowSwipeBehavior.targetOpenedRowID(
                for: -90,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            rowID
        )

        XCTAssertNil(
            RecordingRowSwipeBehavior.targetOpenedRowID(
                for: -(revealWidth / 2),
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
            RecordingRowSwipeBehavior.targetOpenedRowID(
                for: finalOffset,
                rowID: rowID,
                revealWidth: revealWidth
            ),
            rowID
        )
    }
}
