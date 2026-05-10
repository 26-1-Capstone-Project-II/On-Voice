//
//  MyPageView.swift
//  OnVoice
//

import SwiftUI
import PhotosUI

struct MyPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var userProfile: UserProfile
    @State private var showsImageSheet = false
    @State private var showsPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let baseScreenWidth: CGFloat = 393
    private let baseContentHeight: CGFloat = 772
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / baseScreenWidth
            let contentHeight = max(proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom, 1)
            let heightScale = contentHeight / baseContentHeight

            ZStack(alignment: .top) {
                Color.bg.ignoresSafeArea()

                headerView

                ZStack(alignment: .top) {
                    profileSection(widthScale: widthScale)
                        .padding(.top, 70 * heightScale)

                    socialAccountRow(widthScale: widthScale, heightScale: heightScale)
                        .padding(.top, 270 * heightScale)

                    settingsSection(widthScale: widthScale, heightScale: heightScale)
                        .padding(.top, 353 * heightScale)

                    versionInfoRow(widthScale: widthScale, heightScale: heightScale)
                        .padding(.top, 540 * heightScale)

                    logoutRow(widthScale: widthScale, heightScale: heightScale)
                        .padding(.top, 600 * heightScale)
                }
                .frame(maxWidth: .infinity, maxHeight: contentHeight, alignment: .top)
                .padding(.top, 16)

                withdrawalButton()
                    .padding(.bottom, proxy.safeAreaInsets.bottom * heightScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                if showsImageSheet {
                    imageSelectionSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.2), value: showsImageSheet)
        .photosPicker(isPresented: $showsPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newValue in
            guard let newValue else { return }

            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        userProfile.applyCustomImageData(data)
                        selectedPhotoItem = nil
                    }
                } else {
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.main)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
    }

    private func profileSection(widthScale: CGFloat) -> some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())

                Button {
                    showsImageSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray1)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.gray6)
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .offset(x: -1, y: -1)
            }

            if !userProfile.displayNickname.isEmpty {
                Text(userProfile.displayNickname)
                    .font(.Pretendard.Bold.size18)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 144.5 * widthScale)
    }

    @ViewBuilder
    private var profileImageView: some View {
        if let customImageData = userProfile.displayImageData,
           let uiImage = UIImage(data: customImageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let defaultImageName = userProfile.displayImageName {
            Image(defaultImageName)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.gray2)
        }
    }

    private func socialAccountRow(widthScale: CGFloat, heightScale: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text("연결된 소셜 계정")
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.white)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)

                Text("Apple")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.white)
            }
        }
        .padding(.horizontal, 18)
        .frame(width: 345 * widthScale, height: 58 * heightScale)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.gray8, lineWidth: 1.8)
        )
        .frame(maxWidth: .infinity)
    }

    private func settingsSection(widthScale: CGFloat, heightScale: CGFloat) -> some View {
        VStack(spacing: 6 * heightScale) {
            MyPageMenuRow(
                icon: "bell",
                title: "알림 및 권한 설정",
                height: 48 * heightScale
            )
            MyPageMenuRow(icon: "doc.text", title: "개인정보 처리 방침 및 이용약관", height: 48 * heightScale)
            MyPageMenuRow(
                icon: "bubble.left.and.exclamationmark.bubble.right",
                title: "문의하기",
                height: 48 * heightScale
            )
        }
        .frame(width: 345 * widthScale, height: 170 * heightScale)
        .background(Color.gray9)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private func versionInfoRow(widthScale: CGFloat, heightScale: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)

            Text("버전 정보")
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.white)

            Spacer()

            Text(appVersion)
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 18)
        .frame(width: 345 * widthScale, height: 54 * heightScale)
        .frame(maxWidth: .infinity)
    }

    private func logoutRow(widthScale: CGFloat, heightScale: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.right.outward")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)

            Text("로그아웃")
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.white)

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(width: 345 * widthScale, height: 54 * heightScale)
        .frame(maxWidth: .infinity)
    }

    private func withdrawalButton() -> some View {
        Button {} label: {
            Text("회원탈퇴")
                .font(.Pretendard.Medium.size14)
                .foregroundStyle(Color.white.opacity(0.3))
                .underline()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var imageSelectionSheet: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "15161C").opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showsImageSheet = false
                }

            VStack(spacing: 0) {
                Text("이미지 선택하기")
                    .font(.Pretendard.SemiBold.size18)
                    .foregroundStyle(Color.white)
                    .padding(.top, 22)
                    .padding(.bottom, 26)

                Button {
                    userProfile.applyDefaultImageName(
                        MyPageProfileDefaultImage.randomName(
                        excluding: userProfile.defaultImageName.isEmpty ? nil : userProfile.defaultImageName
                        )
                    )
                    showsImageSheet = false
                } label: {
                    sheetRow(systemImage: "photo", title: "기본 이미지로 설정하기")
                }
                .buttonStyle(.plain)

                Button {
                    showsImageSheet = false
                    showsPhotoPicker = true
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
                .foregroundStyle(Color.white)
                .frame(width: 18)

            Text(title)
                .font(.Pretendard.Medium.size18)
                .foregroundStyle(Color.white)

            Spacer()
        }
        .padding(.horizontal, 22)
        .frame(height: 54)
    }

}

private enum MyPageProfileDefaultImage {
    static let names = [
        "profileDefaultYellow",
        "profileDefaultPurple",
        "profileDefaultPink"
    ]

    static func randomName(excluding currentName: String? = nil) -> String {
        let availableNames = names.filter { $0 != currentName }
        return availableNames.randomElement() ?? currentName ?? names[0]
    }
}

private struct MyPageMenuRow: View {
    let icon: String
    let title: String
    let height: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 18)
        .frame(height: height)
    }
}

#Preview {
    NavigationStack {
        MyPageView(userProfile: .constant(.placeholder))
    }
}
