//
//  LoginView.swift
//  OnVoice
//
//  Created by 예은 on 4/7/26.
//

import SwiftUI
import Combine

struct LoginView: View {
    var onLogin: () -> Void = {}

    @State private var selectedPage = 0
    @State private var showsSplash = true

    private let pages = LoginOnboardingPage.all
    private let autoScrollTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    private var loopingPages: [LoginOnboardingPage] {
        guard let firstPage = pages.first else { return [] }
        return pages + [firstPage]
    }

    private var indicatorPage: Int {
        guard !pages.isEmpty else { return 0 }
        return min(selectedPage, pages.count - 1)
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            if showsSplash {
                LoginSplashView()
                    .transition(.opacity)
            } else {
                onboardingContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showsSplash)
        .task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            showsSplash = false
        }
        .onReceive(autoScrollTimer) { _ in
            guard !showsSplash, pages.count > 1 else { return }

            let lastLoopingIndex = loopingPages.count - 1

            withAnimation(.easeInOut(duration: 0.3)) {
                selectedPage += 1
            }

            guard selectedPage == lastLoopingIndex else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                selectedPage = 0
            }
        }
    }

    private var onboardingContent: some View {
        GeometryReader { proxy in
            let referenceWidth: CGFloat = 393
            let contentReferenceHeight: CGFloat = 759
            let contentHeight = proxy.size.height

            let cardHorizontalPadding = proxy.size.width * (18 / referenceWidth)
            let cardTopPadding = contentHeight * (48 / contentReferenceHeight)
            let cardWidth = proxy.size.width - (cardHorizontalPadding * 2)
            let cardHeight = cardWidth * 500 / 357

            let signInHorizontalPadding = proxy.size.width * (24 / referenceWidth)
            let signInTopPadding = contentHeight * (615 / contentReferenceHeight)
            let signInWidth = proxy.size.width * (345 / referenceWidth)
            let signInHeight = proxy.size.height * (58 / 852)

            let signUpHorizontalPadding = proxy.size.width * (24 / referenceWidth)
            let signUpTopPadding = contentHeight * (683 / contentReferenceHeight)
            let signUpWidth = proxy.size.width * (345 / referenceWidth)
            let signUpHeight = proxy.size.height * (58 / 852)

            let indicatorTopPadding = contentHeight * (564 / contentReferenceHeight)

            ZStack(alignment: .top) {
                TabView(selection: $selectedPage) {
                    ForEach(loopingPages.indices, id: \.self) { index in
                        LoginOnboardingCard(
                            imageName: loopingPages[index].imageName,
                            width: cardWidth,
                            height: cardHeight
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: cardWidth, height: cardHeight)
                .padding(.top, cardTopPadding)
                .padding(.horizontal, cardHorizontalPadding)

                pageIndicator
                    .padding(.top, indicatorTopPadding)

                appleButton(
                    title: "Sign in with Apple",
                    foregroundColor: .white,
                    backgroundColor: .black,
                    borderColor: .white.opacity(0.35),
                    action: onLogin
                )
                .frame(width: signInWidth, height: signInHeight)
                .padding(.top, signInTopPadding)
                .padding(.horizontal, signInHorizontalPadding)

                appleButton(
                    title: "Sign up with Apple",
                    foregroundColor: .black,
                    backgroundColor: .white,
                    borderColor: .clear,
                    action: {}
                )
                .frame(width: signUpWidth, height: signUpHeight)
                .padding(.top, signUpTopPadding)
                .padding(.horizontal, signUpHorizontalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 12) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(indicatorPage == index ? Color.main : Color.gray8)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func appleButton(
        title: String,
        foregroundColor: Color,
        backgroundColor: Color,
        borderColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))

                Text(title)
                    .font(.Pretendard.SemiBold.size20)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LoginSplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)

            Image("minglyWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 27)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoginOnboardingCard: View {
    let imageName: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
    }
}

private struct LoginOnboardingPage {
    let imageName: String

    static let all: [LoginOnboardingPage] = [
        LoginOnboardingPage(imageName: "onboardingIntro"),
        LoginOnboardingPage(imageName: "onboardingVoiceCheck"),
        LoginOnboardingPage(imageName: "onboardingNotification"),
        LoginOnboardingPage(imageName: "onboardingAnalysis")
    ]
}

#Preview {
    LoginView()
}
