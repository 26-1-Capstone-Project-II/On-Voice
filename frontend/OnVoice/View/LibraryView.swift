//
//  LibraryView.swift
//  OnVoice
//

import SwiftUI

struct LibraryView: View {
    @Binding var selectedTab: OnVoiceTab
    @State private var isShowingSituationRecognition = false
    @State private var isShowingLibraryOptionsAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeHeaderView(
                        title: "라이브러리",
                        showsProfileButton: true,
                        titleTopOffset: 32,
                        onTitleTrailingButtonTap: {
                            isShowingLibraryOptionsAlert = true
                        }
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("준비 중")
                            .onVoiceTextStyle(.title2, color: .gray1)

                        Text("라이브러리 화면은 다음 단계에서 연결할 수 있도록 자리만 먼저 잡아두었습니다.")
                            .onVoiceTextStyle(.body5, color: .gray4)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .alert("준비 중", isPresented: $isShowingLibraryOptionsAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("라이브러리 추가 옵션은 다음 단계에서 연결할 예정입니다.")
            }
        }
    }
}

#Preview {
    LibraryView(selectedTab: .constant(.library))
}
