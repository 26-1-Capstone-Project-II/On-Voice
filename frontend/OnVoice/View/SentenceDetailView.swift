//
//  SentenceDetailView.swift
//  OnVoice
//
//  Created by Lee YunJi on 8/11/25.
//


import SwiftUI

struct SentenceDetailView: View {
    let sentences: [AnalysisSentence]

    var body: some View {
        ZStack {
            Color.suBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sentences) { s in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("문장 \(s.index)")
                                    .font(.Pretendard.SemiBold.size16)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.0f%%", s.accuracy * 100))
                                    .font(.Pretendard.Medium.size14)
                                    .foregroundColor(s.isCorrect ? .point : .red)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("표준 발음")
                                    .font(.Pretendard.Medium.size14)
                                    .foregroundColor(.suGray3)
                                TokenDiffBubble(pieces: s.referencePieces)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("내 발음")
                                    .font(.Pretendard.Medium.size14)
                                    .foregroundColor(.suGray3)
                                TokenDiffBubble(pieces: s.spokenPieces)
                            }
                        }
                        .padding(14)
                        .background(Color.suGray7)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("상세 비교")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TokenDiffBubble: View {
    let pieces: [AnalysisWordPiece]
    var body: some View {
        // 긴 문장도 줄바꿈 + 세로 스크롤로 안정적으로 표시
        ScrollView(.vertical, showsIndicators: false) {
            Text(makeAttributedString(from: pieces))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.suGray6)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 56)
    }

    private func makeAttributedString(from pieces: [AnalysisWordPiece]) -> AttributedString {
        var result = AttributedString("")
        for (idx, p) in pieces.enumerated() {
            var chunk = AttributedString(p.text + (idx == pieces.count - 1 ? "" : " "))
            chunk.foregroundColor = p.isError ? .red : .white
            result.append(chunk)
        }
        return result
    }
}
