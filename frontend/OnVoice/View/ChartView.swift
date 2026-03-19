//
//  ChartView.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//


import SwiftUI

struct ChartView: View {
    var progress: Double    // 0.0 ~ 1.0
    var scoreText: String   // 중앙에 표시할 점수(예: "82")
    var label: String? = nil
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.suGray6, lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.point, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            
            VStack(spacing: 6) {
                Text(scoreText)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                if let label {
                    Text(label)
                        .font(.Pretendard.Medium.size14)
                        .foregroundColor(.suGray3)
                }
            }
        }
        .frame(width: 220, height: 220)
    }
}
