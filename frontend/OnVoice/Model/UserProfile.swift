//
//  UserProfile.swift
//  OnVoice
//

import Foundation

struct UserProfile: Equatable {
    var nickname: String
    var defaultImageName: String
    var customImageData: Data?

    static let placeholder = UserProfile(
        nickname: "",
        defaultImageName: "",
        customImageData: nil
    )

    var displayNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
