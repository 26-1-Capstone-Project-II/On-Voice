//
//  ProfileSetupView.swift
//  OnVoice
//

import SwiftUI
import PhotosUI
import AVFoundation
import Speech
import UserNotifications

struct ProfileSetupView: View {
    let onNext: () -> Void

    @State private var defaultProfileImageName = ProfileDefaultImage.randomName()
    @FocusState private var isNicknameFocused: Bool
    @State private var nickname = ""
    @State private var showsImageSheet = false
    @State private var showsPermissionSheet = false
    @State private var showsPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedProfileImage: Image?
    @State private var microphonePermission = PermissionState.unknown
    @State private var speechPermission = PermissionState.unknown
    @State private var notificationPermission = PermissionState.unknown

    private let maxNicknameCount = 10

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasText: Bool {
        !nickname.isEmpty
    }

    private var containsOnlyAllowedCharacters: Bool {
        let pattern = "^[가-힣A-Za-z0-9]+$"
        return nickname.range(of: pattern, options: .regularExpression) != nil
    }

    private var exceedsMaxCount: Bool {
        nickname.count > maxNicknameCount
    }

    private var isValidNickname: Bool {
        !trimmedNickname.isEmpty && containsOnlyAllowedCharacters && !exceedsMaxCount
    }

    private var helperMessage: String? {
        guard hasText else { return nil }

        if exceedsMaxCount {
            return "10자 이내로 입력해주세요"
        }

        if !containsOnlyAllowedCharacters {
            return "사용불가능한 닉네임입니다"
        }

        return "사용가능한 닉네임입니다"
    }

    private var helperColor: Color {
        guard hasText else { return .gray5 }
        return isValidNickname ? .main : Color(hex: "#FF5A64")
    }

    private var fieldBorderColor: Color {
        if hasText && !isValidNickname {
            return Color(hex: "#FF5A64")
        }

        if isNicknameFocused {
            return .main
        }

        return .clear
    }

    private var hasRequiredPermissions: Bool {
        microphonePermission == .granted && speechPermission == .granted
    }

    private var hasAllPermissions: Bool {
        hasRequiredPermissions && notificationPermission == .granted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bg.ignoresSafeArea()

            GeometryReader { proxy in
                let widthScale = proxy.size.width / 393
                let contentHeight = max(proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom, 1)
                let heightScale = contentHeight / 793

                ZStack(alignment: .top) {
                    titleView
                        .frame(maxWidth: .infinity)
                        .frame(height: 52 * heightScale)

                    profileImageButton
                        .padding(.top, 88 * heightScale)

                    nicknameSection
                        .padding(.top, 228 * heightScale)
                        .padding(.horizontal, 24 * widthScale)

                    nextButton
                        .frame(width: 345 * widthScale, height: 54 * heightScale)
                        .padding(.top, 683 * heightScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isNicknameFocused = false
            }

            if showsImageSheet {
                imageSelectionSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showsPermissionSheet {
                permissionSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsImageSheet)
        .animation(.easeInOut(duration: 0.2), value: showsPermissionSheet)
        .photosPicker(isPresented: $showsPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newValue in
            guard let newValue else { return }

            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedProfileImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    private var titleView: some View {
        Text("프로필 작성")
            .font(.Pretendard.SemiBold.size18)
            .foregroundStyle(Color.sub)
            .frame(width: 83, height: 18)
            .padding(.vertical, 17)
            .padding(.horizontal, 155)
    }

    private var profileImageButton: some View {
        Button {
            isNicknameFocused = false
            showsImageSheet = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let selectedProfileImage {
                        selectedProfileImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(defaultProfileImageName)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 104, height: 104)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )

                ZStack {
                    Circle()
                        .fill(Color.gray6)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.sub)
                }
                .frame(width: 32, height: 32)
                .offset(x: -1, y: -1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 104)
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("닉네임 입력")
                .font(.Pretendard.SemiBold.size16)
                .foregroundStyle(Color.sub)
                .frame(height: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField("", text: $nickname, prompt: Text("한글,영문,숫자만 가능").foregroundStyle(Color.gray6))
                        .focused($isNicknameFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.Pretendard.SemiBold.size20)
                        .foregroundStyle(Color.sub)
                        .tint(.main)

                    if hasText {
                        Button {
                            nickname = ""
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray8)

                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.gray5)
                            }
                            .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.gray10)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(fieldBorderColor, lineWidth: fieldBorderColor == .clear ? 0 : 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(alignment: .center) {
                    if let helperMessage {
                        Text(helperMessage)
                            .font(.Pretendard.Medium.size14)
                            .foregroundStyle(helperColor)
                    }

                    Spacer()

                    Text("\(nickname.count)/\(maxNicknameCount)")
                        .font(.Pretendard.Medium.size14)
                        .foregroundStyle(hasText && !isValidNickname ? Color(hex: "#FF5A64") : .gray6)
                }
                .frame(height: 18)
                .padding(.trailing, 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextButton: some View {
        Button {
            isNicknameFocused = false
            Task {
                await refreshPermissionStates()
                await MainActor.run {
                    showsPermissionSheet = true
                }
            }
        } label: {
            Text("다음")
                .font(.Pretendard.SemiBold.size20)
                .foregroundStyle(isValidNickname ? Color.sub : Color.gray6)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isValidNickname ? Color.main : Color.main.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isValidNickname)
    }

    private var imageSelectionSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    showsImageSheet = false
                }

            VStack(spacing: 0) {
                Text("이미지 선택하기")
                    .font(.Pretendard.SemiBold.size20)
                    .foregroundStyle(Color.sub)
                    .padding(.top, 22)
                    .padding(.bottom, 26)

                Button {
                    defaultProfileImageName = ProfileDefaultImage.randomName()
                    selectedProfileImage = nil
                    showsImageSheet = false
                } label: {
                    sheetRow(systemImage: "photo", title: "기본 이미지로 설정하기")
                }
                .buttonStyle(.plain)

                Button {
                    showsImageSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showsPhotoPicker = true
                    }
                } label: {
                    sheetRow(systemImage: "photo.on.rectangle.angled", title: "갤러리에서 선택하기")
                }
                .buttonStyle(.plain)

                Capsule()
                    .fill(Color.sub)
                    .frame(width: 134, height: 5)
                    .padding(.top, 26)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(Color.gray10)
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
    }

    private func sheetRow(systemImage: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.sub)
                .frame(width: 18)

            Text(title)
                .font(.Pretendard.Medium.size18)
                .foregroundStyle(Color.sub)

            Spacer()
        }
        .padding(.horizontal, 22)
        .frame(height: 54)
    }

    private var permissionSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.44)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("밍글리가 처음이시군요!")
                    .font(.Pretendard.Bold.size28)
                    .foregroundStyle(Color.sub)
                    .padding(.top, 28)

                Text("아래의 권한을 허용해야 서비스 이용이 가능해요.")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.gray5)
                    .padding(.top, 8)

                Button {
                    Task {
                        await requestAllPermissions()
                    }
                } label: {
                    permissionHighlightRow(
                        title: "전체 권한 허용하기",
                        isGranted: hasAllPermissions
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 28)

                VStack(spacing: 0) {
                    Button {
                        Task {
                            await requestMicrophonePermission()
                        }
                    } label: {
                        permissionRow(
                            title: "마이크 접근 권한 허용",
                            isGranted: microphonePermission == .granted
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await requestSpeechPermission()
                        }
                    } label: {
                        permissionRow(
                            title: "음성 인식 권한 허용",
                            isGranted: speechPermission == .granted
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await requestNotificationPermission()
                        }
                    } label: {
                        permissionRow(
                            title: "휴대폰 알림 권한 허용 (선택)",
                            isGranted: notificationPermission == .granted
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)

                Button {
                    showsPermissionSheet = false
                    onNext()
                } label: {
                    Text("시작하기")
                        .font(.Pretendard.SemiBold.size20)
                        .foregroundStyle(hasRequiredPermissions ? Color.sub : Color.gray6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(hasRequiredPermissions ? Color.main : Color.main.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!hasRequiredPermissions)
                .padding(.top, 34)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray10)
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
        .task {
            await refreshPermissionStates()
        }
    }

    private func permissionHighlightRow(title: String, isGranted: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.Pretendard.SemiBold.size18)
                .foregroundStyle(Color.sub)

            Spacer()

            permissionCheckIcon(isGranted: isGranted)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.gray9)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func permissionRow(title: String, isGranted: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.Pretendard.Medium.size18)
                .foregroundStyle(Color.sub)

            Spacer()

            permissionCheckIcon(isGranted: isGranted)
        }
        .frame(height: 58)
    }

    private func permissionCheckIcon(isGranted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isGranted ? Color.main : Color.main.opacity(0.52))

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.sub)
        }
        .frame(width: 24, height: 24)
    }

    @MainActor
    private func refreshPermissionStates() async {
        microphonePermission = await PermissionRequester.microphoneStatus()
        speechPermission = await PermissionRequester.speechStatus()
        notificationPermission = await PermissionRequester.notificationStatus()
    }

    @MainActor
    private func requestAllPermissions() async {
        microphonePermission = await PermissionRequester.requestMicrophonePermission()
        speechPermission = await PermissionRequester.requestSpeechPermission()
        notificationPermission = await PermissionRequester.requestNotificationPermission()
    }

    @MainActor
    private func requestMicrophonePermission() async {
        microphonePermission = await PermissionRequester.requestMicrophonePermission()
    }

    @MainActor
    private func requestSpeechPermission() async {
        speechPermission = await PermissionRequester.requestSpeechPermission()
    }

    @MainActor
    private func requestNotificationPermission() async {
        notificationPermission = await PermissionRequester.requestNotificationPermission()
    }
}

private enum ProfileDefaultImage {
    static let names = [
        "profileDefaultYellow",
        "profileDefaultPurple",
        "profileDefaultPink"
    ]

    static func randomName() -> String {
        names.randomElement() ?? names[0]
    }
}

private enum PermissionState {
    case unknown
    case granted
    case denied
}

private enum PermissionRequester {
    static func microphoneStatus() async -> PermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    static func speechStatus() async -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    static func notificationStatus() async -> PermissionState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    static func requestMicrophonePermission() async -> PermissionState {
        let isGranted = await AVAudioApplication.requestRecordPermission()
        return isGranted ? .granted : .denied
    }

    static func requestSpeechPermission() async -> PermissionState {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus == .authorized ? .granted : .denied
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized ? .granted : .denied)
            }
        }
    }

    static func requestNotificationPermission() async -> PermissionState {
        let center = UNUserNotificationCenter.current()

        do {
            let isGranted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return isGranted ? .granted : .denied
        } catch {
            return .denied
        }
    }
}

#Preview {
    ProfileSetupView(onNext: {})
}
