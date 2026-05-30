//
//  MinglySplashView.swift
//  OnVoice
//

import SwiftUI

struct MinglySplashView: View {
    var showsWordmark = true

    var body: some View {
        VStack(spacing: 16) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)

            if showsWordmark {
                Image("minglyWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 27)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
