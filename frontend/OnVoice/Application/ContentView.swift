//
//  ContentView.swift
//  OnVoice
//
import SwiftUI

enum OnVoiceTab: Equatable {
    case home
    case library
}

enum OnVoiceFlow: Equatable {
    case login
    case profileSetup
    case app
}

struct ContentView: View {
    @State private var selectedTab: OnVoiceTab = .home
    @State private var flow: OnVoiceFlow
    @State private var userProfile: UserProfile
    @State private var showsLaunchSplash: Bool

    init() {
        let currentUserIdentifier = AppleSignInSession.currentUserIdentifier
        let savedProfile = currentUserIdentifier.flatMap { userIdentifier in
            UserProfileStore.migrateLegacyProfileIfNeeded(for: userIdentifier)
            return UserProfileStore.load(for: userIdentifier)
        }
        let shouldRestoreApp = currentUserIdentifier != nil && savedProfile != nil

        _userProfile = State(initialValue: savedProfile ?? .placeholder)
        _showsLaunchSplash = State(initialValue: shouldRestoreApp)

        if currentUserIdentifier != nil {
            _flow = State(initialValue: savedProfile == nil ? .profileSetup : .app)
        } else {
            _flow = State(initialValue: .login)
        }
    }

    var body: some View {
        ZStack {
            if showsLaunchSplash {
                MinglySplashView(showsWordmark: false)
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsLaunchSplash)
        .background(Color.bg)
        .task {
            guard showsLaunchSplash else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showsLaunchSplash = false
        }
        .onChange(of: userProfile) { newValue in
            guard flow == .app else { return }
            saveProfile(newValue)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flow {
        case .login:
            LoginView {
                handleLogin()
            }
        case .profileSetup:
            ProfileSetupView { profile in
                saveProfile(profile)
                userProfile = profile
                flow = .app
            }
        case .app:
            switch selectedTab {
            case .home:
                HomeView(
                    selectedTab: $selectedTab,
                    userProfile: $userProfile,
                    onLogout: handleLogout,
                    onWithdrawal: handleWithdrawal
                )
            case .library:
                LibraryView(
                    selectedTab: $selectedTab,
                    userProfile: $userProfile,
                    onLogout: handleLogout,
                    onWithdrawal: handleWithdrawal
                )
            }
        }
    }

    private func handleLogin() {
        guard let userIdentifier = AppleSignInSession.currentUserIdentifier else {
            flow = .login
            return
        }

        UserProfileStore.migrateLegacyProfileIfNeeded(for: userIdentifier)

        if let savedProfile = UserProfileStore.load(for: userIdentifier) {
            userProfile = savedProfile
            selectedTab = .home
            flow = .app
        } else {
            userProfile = .placeholder
            flow = .profileSetup
        }
    }

    private func handleLogout() {
        AppleSignInSession.clear()
        userProfile = .placeholder
        selectedTab = .home
        showsLaunchSplash = false
        flow = .login
    }

    private func handleWithdrawal() {
        if let userIdentifier = AppleSignInSession.currentUserIdentifier {
            UserProfileStore.clear(for: userIdentifier)
        }

        handleLogout()
    }

    private func saveProfile(_ profile: UserProfile) {
        guard let userIdentifier = AppleSignInSession.currentUserIdentifier else { return }
        UserProfileStore.save(profile, for: userIdentifier)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioRecorder())
}
