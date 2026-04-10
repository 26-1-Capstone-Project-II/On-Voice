//
//  BottomDockView.swift
//  OnVoice
//

import SwiftUI

struct BottomDockView: View {
    @Binding var selectedTab: OnVoiceTab
    let onAddTap: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                bottomItem(
                    tab: .home,
                    title: "홈",
                    systemImage: "house.fill"
                )

                bottomItem(
                    tab: .library,
                    title: "라이브러리",
                    systemImage: "books.vertical.fill"
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: 208, height: 62)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.sub.opacity(0.2))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            Spacer()

            Button(action: onAddTap) {
                ZStack {
                    Circle()
                        .fill(Color.sub.opacity(0.2))

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.gray5)
                }
                .frame(width: 56, height: 56)
                .padding(.bottom, 4)    //
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 0)
    }

    @ViewBuilder
    private func bottomItem(tab: OnVoiceTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))

                Text(title)
                    .onVoiceTextStyle(.caption1)
            }
            .foregroundStyle(isSelected ? Color.main : Color.gray9)
            .frame(width: 98, height: 54)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.sub.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BottomDockView(selectedTab: .constant(.home), onAddTap: {})
        .background(Color.bg)
}
