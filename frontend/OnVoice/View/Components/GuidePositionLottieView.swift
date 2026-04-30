//
//  GuidePositionLottieView.swift
//  OnVoice
//
//  Created by Codex on 5/1/26.
//

import SwiftUI
import DotLottie

struct GuidePositionLottieView: View {
    private let size: CGFloat = 223
    private let visualScale: CGFloat = 2.05
    private let animation = DotLottieAnimation(
        fileName: "position",
        config: AnimationConfig(
            autoplay: true,
            loop: true
        )
    )

    var body: some View {
        animation.view()
            .frame(width: size, height: size)
            .scaleEffect(visualScale)
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.bg.ignoresSafeArea()
        GuidePositionLottieView()
    }
}
