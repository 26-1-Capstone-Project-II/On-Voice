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
            let cardWidth = min(proxy.size.width - 32, 357)
            let cardHeight = cardWidth * 500 / 357

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: max(40, proxy.safeAreaInsets.top + 34))

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
                .frame(height: cardHeight)

                pageIndicator
                    .padding(.top, 14)

                Spacer(minLength: 34)

                VStack(spacing: 14) {
                    appleButton(
                        title: "Sign in with apple",
                        foregroundColor: .white,
                        backgroundColor: .black,
                        borderColor: .white.opacity(0.35),
                        action: onLogin
                    )

                    appleButton(
                        title: "Sign up with apple",
                        foregroundColor: .black,
                        backgroundColor: .white,
                        borderColor: .clear,
                        action: {}
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 20))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var pageIndicator: some View {
                HStack(spacing: 10) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(indicatorPage == index ? Color.main : Color.gray8)
                            .frame(width: 11, height: 11)
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
                    .font(.Pretendard.SemiBold.size18)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
