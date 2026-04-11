//
//  EmptyRecordView.swift
//  OnVoice
//

import SwiftUI

struct EmptyRecordView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("minglyWatermark")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.gray9)
                .scaledToFit()
                .frame(width: 256, height: 256)
                .opacity(0.5)
                .padding(.trailing, 9)  // 오른쪽에 패딩 9만큼 더 추가


            Text("기록이 없어요")
                .font(.Pretendard.SemiBold.size22)
                .foregroundStyle(Color.gray9.opacity(0.5))
        }
    }
}

#Preview {
    EmptyRecordView()
        .background(Color.bg)
}
