//
//  LoginView.swift
//  OnVoice
//
//  Created by 예은 on 4/7/26.
//

import SwiftUI
import Combine
import AuthenticationServices

struct LoginView: View {
    var onLogin: () -> Void = {}

    @State private var selectedPage = 0
    @State private var showsSplash = true
    @State private var lastManualSwipeAt: Date?
    @State private var signInErrorMessage: String?
    @State private var showsSignInError = false

    private let pages = LoginOnboardingPage.all
    private let autoScrollTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    private let autoScrollPauseAfterSwipe: TimeInterval = 3.0

    private var loopingPages: [LoginOnboardingPage] {
        guard let firstPage = pages.first else { return [] }
        return pages + [firstPage]
    }

    private var indicatorPage: Int {
        guard !pages.isEmpty else { return 0 }
        return selectedPage == pages.count ? 0 : min(selectedPage, pages.count - 1)
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            if showsSplash {
                MinglySplashView()
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
            if let lastManualSwipeAt,
               Date().timeIntervalSince(lastManualSwipeAt) < autoScrollPauseAfterSwipe {
                return
            }
            let lastLoopingIndex = loopingPages.count - 1

            withAnimation(.easeInOut(duration: 0.28)) {
                selectedPage += 1
            }

            guard selectedPage == lastLoopingIndex else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    selectedPage = 0
                }
            }
        }
        .onChange(of: selectedPage) { newValue in
            guard pages.count > 1 else { return }
            guard newValue == pages.count else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard selectedPage == pages.count else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    selectedPage = 0
                }
            }
        }
        .alert("Apple 로그인에 실패했어요", isPresented: $showsSignInError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(signInErrorMessage ?? "잠시 후 다시 시도해주세요.")
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
                        ZStack {
                            LoginOnboardingCard(
                                imageName: loopingPages[index].imageName,
                                width: cardWidth,
                                height: cardHeight
                            )
                        }
                        .frame(width: proxy.size.width, height: cardHeight)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: cardHeight)
                .padding(.top, cardTopPadding)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            lastManualSwipeAt = Date()
                        }
                )

                pageIndicator
                    .padding(.top, indicatorTopPadding)

                appleSignInButton(type: .signIn, style: .black)
                .frame(width: signInWidth, height: signInHeight)
                .padding(.top, signInTopPadding)
                .padding(.horizontal, signInHorizontalPadding)

                appleSignInButton(type: .signUp, style: .white)
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

    private func appleSignInButton(
        type: SignInWithAppleButton.Label,
        style: SignInWithAppleButton.Style
    ) -> some View {
        SignInWithAppleButton(type) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleAppleSignInCompletion(result)
        }
        .signInWithAppleButtonStyle(style)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                presentSignInError("Apple 계정 정보를 확인할 수 없어요.")
                return
            }

            AppleSignInSession.store(credential)
            onLogin()
        case .failure(let error):
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            presentSignInError("잠시 후 다시 시도해주세요.")
        }
    }

    private func presentSignInError(_ message: String) {
        signInErrorMessage = message
        showsSignInError = true
    }
}

enum AppleSignInSession {
    private static let userIdentifierKey = "appleSignInUserIdentifier"

    static var currentUserIdentifier: String? {
        UserDefaults.standard.string(forKey: userIdentifierKey)
    }

    static func store(_ credential: ASAuthorizationAppleIDCredential) {
        UserDefaults.standard.set(credential.user, forKey: userIdentifierKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userIdentifierKey)
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
