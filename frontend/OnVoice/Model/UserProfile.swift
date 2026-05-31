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

    static func load(
        for userIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> UserProfile? {
        guard let data = userDefaults.data(forKey: profileKey(for: userIdentifier)) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func save(
        _ profile: UserProfile,
        for userIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) {
        guard !profile.displayNickname.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(profile) else { return }
        userDefaults.set(data, forKey: profileKey(for: userIdentifier))
    }

    static func clear(
        for userIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.removeObject(forKey: profileKey(for: userIdentifier))
    }

    static func migrateLegacyProfileIfNeeded(
        for userIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) {
        guard userDefaults.data(forKey: profileKey(for: userIdentifier)) == nil,
              let legacyData = userDefaults.data(forKey: legacyProfileKey),
              let legacyProfile = try? JSONDecoder().decode(UserProfile.self, from: legacyData),
              let migratedData = try? JSONEncoder().encode(legacyProfile) else {
            return
        }

        userDefaults.set(migratedData, forKey: profileKey(for: userIdentifier))
        userDefaults.removeObject(forKey: legacyProfileKey)
    }

    private static func profileKey(for userIdentifier: String) -> String {
        profileKeyPrefix + userIdentifier
    }
}
