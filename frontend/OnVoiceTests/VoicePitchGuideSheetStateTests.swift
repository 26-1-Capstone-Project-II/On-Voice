import CoreGraphics
import XCTest
@testable import OnVoice

final class VoicePitchGuideSheetStateTests: XCTestCase {
    func testAutomaticPresentationHonorsSkipPreference() {
        XCTAssertTrue(
            VoicePitchGuideSheetState.shouldAutoPresent(skipPreference: false)
        )
        XCTAssertFalse(
            VoicePitchGuideSheetState.shouldAutoPresent(skipPreference: true)
        )
    }

    func testPresentationSourceControlsDoNotShowAgainVisibility() {
        XCTAssertTrue(
            VoicePitchGuideSheetPresentationSource.automatic.showsDoNotShowAgainButton
        )
        XCTAssertFalse(
            VoicePitchGuideSheetPresentationSource.manual.showsDoNotShowAgainButton
        )
    }

    func testManualPresentationResetsTransientStateEvenWhenSkipPreferenceExists() {
        var state = VoicePitchGuideSheetState(
            isPresented: false,
            isVisible: true,
            isDismissing: false,
            dragOffset: 88,
            source: .automatic
        )

        let transition = state.prepareForPresentation(source: .manual)

        XCTAssertEqual(transition, .insertedHidden)
        XCTAssertTrue(state.isPresented)
        XCTAssertFalse(state.isVisible)
        XCTAssertEqual(state.dragOffset, 0)
        XCTAssertEqual(state.source, .manual)
        XCTAssertFalse(state.source.showsDoNotShowAgainButton)
    }

    func testReopeningExistingSheetKeepsItPresentButUpdatesSource() {
        var state = VoicePitchGuideSheetState(
            isPresented: true,
            isVisible: false,
            isDismissing: false,
            dragOffset: 42,
            source: .automatic
        )

        let transition = state.prepareForPresentation(source: .manual)

        XCTAssertEqual(transition, .revealExistingSheet)
        XCTAssertTrue(state.isPresented)
        XCTAssertFalse(state.isVisible)
        XCTAssertEqual(state.dragOffset, 0)
        XCTAssertEqual(state.source, .manual)
    }

    func testDismissalThresholdAndStateReset() {
        XCTAssertFalse(
            VoicePitchGuideSheetState.shouldDismiss(
                for: 119,
                threshold: 120
            )
        )
        XCTAssertTrue(
            VoicePitchGuideSheetState.shouldDismiss(
                for: 120,
                threshold: 120
            )
        )

        var state = VoicePitchGuideSheetState(
            isPresented: true,
            isVisible: true,
            isDismissing: false,
            dragOffset: 64,
            source: .automatic
        )

        XCTAssertTrue(state.beginDismissal())
        XCTAssertTrue(state.isDismissing)
        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.dragOffset, 64)

        state.prepareForDismissalAnimation()

        XCTAssertFalse(state.isVisible)
        XCTAssertEqual(state.dragOffset, 0)

        state.completeDismissal()

        XCTAssertFalse(state.isPresented)
        XCTAssertFalse(state.isDismissing)
        XCTAssertEqual(state.dragOffset, 0)
    }
}
