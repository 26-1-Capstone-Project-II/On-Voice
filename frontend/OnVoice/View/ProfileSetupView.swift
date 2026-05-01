//
//  ProfileSetupView.swift
//  OnVoice
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    let onNext: () -> Void

    @State private var defaultProfileImageName = ProfileDefaultImage.randomName()
    @FocusState private var isNicknameFocused: Bool
    @State private var nickname = ""
    @State private var showsImageSheet = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedProfileImage: Image?

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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("프로필 작성")
                    .font(.Pretendard.SemiBold.size18)
                    .foregroundStyle(Color.sub)
                    .padding(.top, 65)

                profileImageButton
                    .padding(.top, 47)

                nicknameSection
                    .padding(.top, 41)

                Spacer()

                nextButton
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                isNicknameFocused = false
            }

            if showsImageSheet {
                imageSelectionSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsImageSheet)
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
                .frame(width: 118, height: 118)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )

                ZStack {
                    Circle()
                        .fill(Color.gray6)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.sub)
                }
                .frame(width: 36, height: 36)
                .offset(x: -2, y: -2)
            }
        }
        .buttonStyle(.plain)
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("닉네임 입력")
                .font(.Pretendard.SemiBold.size16)
                .foregroundStyle(Color.sub)

            VStack(alignment: .leading, spacing: 6) {
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
                .frame(height: 50)
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
            }
        }
        .padding(.horizontal, 22)
    }

    private var nextButton: some View {
        Button(action: onNext) {
            Text("다음")
                .font(.Pretendard.SemiBold.size20)
                .foregroundStyle(isValidNickname ? Color.sub : Color.gray6)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
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

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    sheetRow(systemImage: "photo.on.rectangle.angled", title: "갤러리에서 선택하기")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    showsImageSheet = false
                })

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

#Preview {
    ProfileSetupView(onNext: {})
}
