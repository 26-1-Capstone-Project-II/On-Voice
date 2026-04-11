//
//  LibraryView.swift
//  OnVoice
//

import SwiftUI

struct LibraryView: View {
    @Binding var selectedTab: OnVoiceTab
    @State private var isShowingSituationRecognition = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    HomeHeaderView(
                        title: "라이브러리",
                        showsProfileButton: false
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("준비 중")
                            .onVoiceTextStyle(.title2, color: .gray1)

                        Text("라이브러리 화면은 다음 단계에서 연결할 수 있도록 자리만 먼저 잡아두었습니다.")
                            .onVoiceTextStyle(.body5, color: .gray4)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 18)

                    Spacer()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomDockView(
                    selectedTab: $selectedTab,
                    onAddTap: { isShowingSituationRecognition = true }
                )
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSituationRecognition) {
                SituationRecognitionView()
            }
        }
    }
}

#Preview {
    LibraryView(selectedTab: .constant(.library))
}
