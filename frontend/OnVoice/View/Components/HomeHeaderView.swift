//
//  HomeHeaderView.swift
//  OnVoice
//

import SwiftUI

struct HomeHeaderView: View {
    let title: String
    var showsProfileButton: Bool = true
    private let headerHeight: CGFloat = 152

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
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(.leading, 18)
                    .padding(.top, 22)

                Text(title)
                    .onVoiceTextStyle(.head2, color: .sub)
                    .padding(.leading, 18)
                    .padding(.top, 70)

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
                    .padding(.trailing, 18)
                    .padding(.top, 18)
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
