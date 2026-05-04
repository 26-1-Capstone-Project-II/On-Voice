//
//  VoicePitchGuideSheetState.swift
//  OnVoice
//

import CoreGraphics

enum VoicePitchGuideSheetPresentationSource: Equatable {
    case automatic
    case manual

    // "Do not show again" only applies to the first automatic presentation.
    var showsDoNotShowAgainButton: Bool {
        self == .automatic
    }
}

struct VoicePitchGuideSheetState: Equatable {
    enum PresentationTransition: Equatable {
        case blocked
        case insertedHidden
        case revealExistingSheet
        case alreadyVisible
    }

    var isPresented = false
    var isVisible = false
    var isDismissing = false
    var dragOffset: CGFloat = 0
    var source: VoicePitchGuideSheetPresentationSource = .automatic

    static func shouldAutoPresent(skipPreference: Bool) -> Bool {
        !skipPreference
    }

    static func shouldDismiss(
        for translationHeight: CGFloat,
        threshold: CGFloat
    ) -> Bool {
        translationHeight >= threshold
    }

    mutating func prepareForPresentation(
        source: VoicePitchGuideSheetPresentationSource
    ) -> PresentationTransition {
        guard !isDismissing else { return .blocked }

        self.source = source
        dragOffset = 0

        guard isPresented else {
            isVisible = false
            isPresented = true
            return .insertedHidden
        }

        guard !isVisible else {
            return .alreadyVisible
        }

        return .revealExistingSheet
    }

    mutating func reveal() {
        isVisible = true
    }

    mutating func beginDismissal() -> Bool {
        guard isPresented, !isDismissing else { return false }

        isDismissing = true
        return true
    }

    mutating func prepareForDismissalAnimation() {
        dragOffset = 0
        isVisible = false
    }

    mutating func completeDismissal() {
        isPresented = false
        isDismissing = false
        dragOffset = 0
    }

    mutating func updateDragOffset(with translationHeight: CGFloat) {
        guard !isDismissing else { return }
        dragOffset = max(translationHeight, 0)
    }

    mutating func resetDragOffset() {
        dragOffset = 0
    }
}
