//
//  VoicePitchGuideBottomSheet.swift
//  OnVoice
//
//  Created by Codex on 4/30/26.
//

import SwiftUI

struct VoicePitchGuideBottomSheet: View {
    let onConfirm: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 36)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.gray9)
                        .frame(width: 64, height: 6)
                        .padding(.top, 16)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged(onDragChanged)
                        .onEnded(onDragEnded)
                )

            VStack(spacing: 0) {
                Text("스마트폰 위치 설정")
                    .font(.Pretendard.SemiBold.size12)
                    .kerning(-0.3)
                    .foregroundStyle(Color.sub)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Color.gray9)
                    .clipShape(Capsule())
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .padding(.top, 22)
                .padding(.horizontal, 24)

                Text("팔을 자연스럽게 내렸을 때\n손이 위치하는 거리에 스마트폰을 내려주세요")
                    .font(.Pretendard.SemiBold.size18)
                    .kerning(-0.43)
                    .foregroundStyle(Color.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.top, 18)
                    .padding(.horizontal, 32)

                GuidePositionLottieView()
                    .padding(.top, 20)

                Button(action: onConfirm) {
                    Text("확인")
                        .font(.Pretendard.SemiBold.size16)
                        .kerning(-0.3)
                        .foregroundStyle(Color.sub)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.main)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 29)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.gray10, Color.bg],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(
            RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: -6)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.bg.ignoresSafeArea()
        VoicePitchGuideBottomSheet(
            onConfirm: {},
            onDragChanged: { _ in },
            onDragEnded: { _ in }
        )
    }
}
