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

    var displayImageName: String? {
        guard customImageData == nil else { return nil }
        return defaultImageName.isEmpty ? nil : defaultImageName
    }

    var displayImageData: Data? {
        customImageData
    }

    mutating func applyDefaultImageName(_ imageName: String) {
        defaultImageName = imageName
        customImageData = nil
    }

    mutating func applyCustomImageData(_ imageData: Data) {
        customImageData = imageData
    }
}
