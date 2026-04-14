//
//  HomeHeaderView.swift
//  OnVoice
//

import SwiftUI

struct HomeHeaderView: View {
    let title: String
    var showsProfileButton: Bool = true
    var titleTopOffset: CGFloat = 0
    private let headerHeight: CGFloat = 152
    private let horizontalPadding: CGFloat = 18
    private let logoTopPadding: CGFloat = 22
    private let profileButtonTopPadding: CGFloat = 18
    private let headerContentSpacing: CGFloat = 24
    var onTitleTrailingButtonTap: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.bg)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            Color.main.opacity(0.28),
                            Color.main.opacity(0.14),
                            Color.main.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            Color.main.opacity(0.08),
                            Color.main.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: headerHeight)
                .ignoresSafeArea(edges: .top)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: headerContentSpacing) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    HStack(alignment: .top, spacing: 12) {
                        Text(title)
                            .onVoiceTextStyle(.head2, color: .sub)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let onTitleTrailingButtonTap {
                            Button(action: onTitleTrailingButtonTap) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.gray6)
                                    .frame(width: 44, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("추가 옵션")
                        }
                    }
                    .padding(.top, titleTopOffset)
                }
                .padding(.top, logoTopPadding)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if showsProfileButton {
                    Button {} label: {
                        ZStack {
                            Circle()
                                .fill(Color.gray8.opacity(0.92))

                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray2)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, horizontalPadding)
                    .padding(.top, profileButtonTopPadding)
                }
            }
            .frame(height: headerHeight)
        }
        .frame(height: headerHeight)
    }
}

#Preview {
    HomeHeaderView(title: "2026년\n10월 24일 목요일")
        .background(Color.bg)
}
