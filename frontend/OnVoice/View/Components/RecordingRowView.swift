//
//  RecordingRowView.swift
//  OnVoice
//

import SwiftUI

struct RecordingRowView: View {
    let id: Recording.ID
    let title: String
    let subtitle: String
    @Binding var openedRowID: Recording.ID?
    let onTap: () -> Void

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let revealWidth: CGFloat = 148

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons

            cardContent
                .offset(x: currentOffset)
                .gesture(dragGesture)
                .onAppear {
                    restingOffset = targetOffset(for: openedRowID)
                }
                .onChange(of: openedRowID) { newValue in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        restingOffset = targetOffset(for: newValue)
                    }
                }
                .onTapGesture {
                    if isOpened {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            openedRowID = nil
                        }
                    } else {
                        onTap()
                    }
                }
        }
        .frame(height: 68)
        .contentShape(Rectangle())
    }

    private var currentOffset: CGFloat {
        let proposedOffset = restingOffset + dragTranslation
        return min(0, max(-revealWidth, proposedOffset))
    }

    private var isOpened: Bool {
        openedRowID == id
    }

    private var cardContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.absent)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .onVoiceTextStyle(.body3, color: .gray1)

                Text(subtitle)
                    .onVoiceTextStyle(.body5, color: .gray2)
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.gray1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(Color.gray7)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            actionButton(
                systemImage: "pencil",
                title: "수정",
                fillColor: Color(uiColor: .systemIndigo)
            )

            actionButton(
                systemImage: "trash",
                title: "삭제",
                fillColor: Color(uiColor: .systemRed)
            )
        }
        .padding(.trailing, 8)
    }

    private func actionButton(systemImage: String, title: String, fillColor: Color) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(fillColor)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text(title)
                .onVoiceTextStyle(.caption1, color: .gray5)
        }
        .frame(width: 48)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragTranslation) { value, state, _ in
                if value.translation.width < 0, openedRowID != nil, openedRowID != id {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        openedRowID = nil
                    }
                }
                state = value.translation.width
            }
            .onEnded { value in
                let current = min(0, max(-revealWidth, restingOffset + value.translation.width))
                let targetRowID: Recording.ID? = current < -revealWidth / 2 ? id : nil

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    restingOffset = current
                }

                if targetRowID == openedRowID {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        restingOffset = targetOffset(for: targetRowID)
                    }
                } else {
                    openedRowID = targetRowID
                }
            }
    }

    private func targetOffset(for rowID: Recording.ID?) -> CGFloat {
        rowID == id ? -revealWidth : 0
    }
}

#Preview {
    RecordingRowView(
        id: URL(fileURLWithPath: "/tmp/preview.m4a"),
        title: "새로운 대화 기록 (4)",
        subtitle: "2026년 9월 2일 오후 6시 42분 • 49초",
        openedRowID: .constant(nil),
        onTap: {}
    )
    .padding()
    .background(Color.bg)
}
