//
//  UserProfile.swift
//  OnVoice
//

import Foundation

struct UserProfile: Codable, Equatable {
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

enum UserProfileStore {
    private static let legacyProfileKey = "userProfile"
    private static let profileKeyPrefix = "userProfile."

    static func load(for userIdentifier: String) -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileKey(for: userIdentifier)) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func save(_ profile: UserProfile, for userIdentifier: String) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey(for: userIdentifier))
    }

    static func clear(for userIdentifier: String) {
        UserDefaults.standard.removeObject(forKey: profileKey(for: userIdentifier))
    }

    static func migrateLegacyProfileIfNeeded(for userIdentifier: String) {
        guard UserDefaults.standard.data(forKey: profileKey(for: userIdentifier)) == nil,
              let legacyData = UserDefaults.standard.data(forKey: legacyProfileKey) else {
            return
        }

        UserDefaults.standard.set(legacyData, forKey: profileKey(for: userIdentifier))
        UserDefaults.standard.removeObject(forKey: legacyProfileKey)
    }

    private static func profileKey(for userIdentifier: String) -> String {
        profileKeyPrefix + userIdentifier
    }
}
