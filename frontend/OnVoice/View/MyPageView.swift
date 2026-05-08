//
//  MyPageView.swift
//  OnVoice
//

import SwiftUI

struct MyPageView: View {
    @Environment(\.dismiss) private var dismiss

    private let defaultProfileImageName = "profileDefaultYellow"
    private let nickname = "도연바보뽕뽕삼"

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileSection
                            .padding(.top, 22)

                        socialAccountRow
                            .padding(.top, 28)

                        settingsSection
                            .padding(.top, 24)

                        infoSection
                            .padding(.top, 28)

                        Spacer(minLength: 116)

                        withdrawalButton
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

    private var profileSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(defaultProfileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())

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

            Text(nickname)
                .font(.Pretendard.SemiBold.size20)
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private var socialAccountRow: some View {
        HStack(spacing: 12) {
            Text("연결된 소셜 계정")
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.sub)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.sub)

                Text("Apple")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.sub)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray8, lineWidth: 1)
        )
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            MyPageMenuRow(icon: "bell", title: "알림 및 권한 설정")
            divider
            MyPageMenuRow(icon: "doc.text", title: "개인정보 처리 방침 및 이용약관")
            divider
            MyPageMenuRow(icon: "message", title: "문의하기")
        }
        .background(Color.gray9)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.gray4)
                    .frame(width: 20, height: 20)

                Text("버전 정보")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.sub)

                Spacer()

                Text("1.0.1")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.gray5)
            }
            .frame(height: 54)

            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.gray4)
                    .frame(width: 20, height: 20)

                Text("로그아웃")
                    .font(.Pretendard.Medium.size16)
                    .foregroundStyle(Color.sub)

                Spacer()
            }
            .frame(height: 54)
        }
    }

    private var withdrawalButton: some View {
        Button {} label: {
            Text("회원탈퇴")
                .font(.Pretendard.Medium.size14)
                .foregroundStyle(Color.gray6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray8)
            .frame(height: 1)
            .padding(.leading, 52)
    }
}

private struct MyPageMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.gray3)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.Pretendard.Medium.size16)
                .foregroundStyle(Color.sub)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.gray5)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
    }
}

#Preview {
    NavigationStack {
        MyPageView()
    }
}
