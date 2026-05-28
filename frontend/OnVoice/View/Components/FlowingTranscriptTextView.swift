//
//  FlowingTranscriptTextView.swift
//  OnVoice
//
//  오류 발음 스크립트의 "이어지는 흐름 + 문장별 탭" 을 동시에 만족하는 뷰.
//
//  SwiftUI Text 연결(`+`)로는 인라인 흐름은 되지만 span(문장) 단위 탭 콜백을
//  줄 수 없다. 그래서 UITextView 의 layoutManager 로 탭 좌표 → 글리프 → 문자
//  인덱스 → 문장을 역추적해 문장 단위 선택을 구현한다(이슈 #106).
//
//  - 모든 문장을 하나의 NSAttributedString 으로 이어 붙여 자연스러운 줄바꿈 유지
//  - 문장별 NSRange 를 보관해 탭 위치를 문장으로 매핑
//  - 선택 시 다른 문장은 alpha 0.5 로 dim, 선택 문장은 상단 근처로 스크롤
//

import SwiftUI
import UIKit

struct FlowingTranscriptTextView: UIViewRepresentable {
    let sentences: [PronunciationTranscriptSentence]
    /// 현재 선택된 문장의 errorDetail.id (PronunciationErrorScriptView 와 동일 규약).
    let selectedSentenceID: UUID?
    /// 선택이 없을 때 문장을 탭하면 호출. 선택 여부/errorDetail 판단은 부모가 한다.
    let onTapSentence: (PronunciationTranscriptSentence) -> Void
    /// 이미 선택된 상태에서 아무 곳이나 탭하면 호출(해제).
    let onTapWhileSelected: () -> Void

    private enum Metrics {
        static let font = UIFont(name: "Pretendard-Medium", size: 20)
            ?? .systemFont(ofSize: 20, weight: .medium)
        static let lineSpacing: CGFloat = 4
        static let inset = UIEdgeInsets(top: 10, left: 24, bottom: 34, right: 24)
        /// 선택 문장을 상단으로 끌어올릴 때 남길 위쪽 여백.
        static let selectionTopGap: CGFloat = 8
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = Metrics.inset
        textView.textContainer.lineFragmentPadding = 0

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        textView.addGestureRecognizer(tap)

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let savedOffset = textView.contentOffset
        let build = coordinator.buildAttributedText()
        textView.attributedText = build.attributed
        coordinator.sentenceRanges = build.ranges

        // 선택 중에는 선택 문장을 위로 끌어올릴 수 있도록 하단 여백 확보.
        textView.contentInset.bottom = selectedSentenceID == nil ? 0 : textView.bounds.height

        if selectedSentenceID == nil {
            coordinator.resetScrollTracking()
            textView.setContentOffset(savedOffset, animated: false)
        } else if coordinator.shouldScrollToNewSelection() {
            coordinator.scrollToSelection(topGap: Metrics.selectionTopGap)
        } else {
            textView.setContentOffset(savedOffset, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: FlowingTranscriptTextView
        weak var textView: UITextView?
        var sentenceRanges: [SentenceRange] = []
        private var lastScrolledSelectionID: UUID?

        struct SentenceRange {
            let sentence: PronunciationTranscriptSentence
            let range: NSRange
        }

        init(_ parent: FlowingTranscriptTextView) {
            self.parent = parent
        }

        // MARK: Attributed string

        func buildAttributedText() -> (attributed: NSAttributedString, ranges: [SentenceRange]) {
            let result = NSMutableAttributedString()
            var ranges: [SentenceRange] = []

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = Metrics.lineSpacing

            let hasSelection = parent.selectedSentenceID != nil

            for sentence in parent.sentences {
                let start = result.length
                let isSelected = sentence.errorDetail?.id == parent.selectedSentenceID
                let dimmed = hasSelection && !isSelected

                for segment in sentence.segments {
                    var color = UIColor(segment.color)
                    if dimmed { color = color.withAlphaComponent(0.5) }
                    result.append(NSAttributedString(
                        string: segment.text,
                        attributes: [
                            .font: Metrics.font,
                            .foregroundColor: color,
                            .paragraphStyle: paragraph
                        ]
                    ))
                }

                ranges.append(SentenceRange(
                    sentence: sentence,
                    range: NSRange(location: start, length: result.length - start)
                ))
            }
            return (result, ranges)
        }

        // MARK: Tap → sentence

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView else { return }

            // 선택된 상태에서는 어디를 탭하든 해제.
            if parent.selectedSentenceID != nil {
                parent.onTapWhileSelected()
                return
            }

            let location = gesture.location(in: textView)
            let point = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )
            let layoutManager = textView.layoutManager
            let container = textView.textContainer

            // 빈 영역(글자 없는 곳) 오탭 방지: 탭이 실제 글리프 box 안인지 확인.
            let glyphIndex = layoutManager.glyphIndex(for: point, in: container)
            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: container
            )
            guard glyphRect.contains(point) else { return }

            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            guard let match = sentenceRanges.first(where: {
                NSLocationInRange(charIndex, $0.range)
            }) else { return }

            parent.onTapSentence(match.sentence)
        }

        // MARK: Scroll to selection

        func resetScrollTracking() {
            lastScrolledSelectionID = nil
        }

        /// 선택이 새 값으로 바뀌었는지(중복 스크롤 방지).
        func shouldScrollToNewSelection() -> Bool {
            guard let id = parent.selectedSentenceID else { return false }
            return id != lastScrolledSelectionID
        }

        func scrollToSelection(topGap: CGFloat) {
            guard let textView,
                  let id = parent.selectedSentenceID,
                  let match = sentenceRanges.first(where: {
                      $0.sentence.errorDetail?.id == id
                  }) else { return }

            lastScrolledSelectionID = id

            let layoutManager = textView.layoutManager
            layoutManager.ensureLayout(for: textView.textContainer)

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: match.range,
                actualCharacterRange: nil
            )
            let rect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textView.textContainer
            )
            let targetY = max(0, rect.minY + textView.textContainerInset.top - topGap)

            DispatchQueue.main.async {
                textView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
            }
        }
    }
}
