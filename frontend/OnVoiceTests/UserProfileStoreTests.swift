//
//  UserProfileStoreTests.swift
//  OnVoiceTests
//

import XCTest
@testable import OnVoice

final class UserProfileStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "UserProfileStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if let suiteName {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testSaveAndLoadStoresProfilePerUserIdentifier() {
        let profile = UserProfile(
            nickname: "밍글리",
            defaultImageName: "profileDefaultYellow",
            customImageData: Data([1, 2, 3])
        )

        UserProfileStore.save(profile, for: "apple-user-1", userDefaults: userDefaults)

        XCTAssertEqual(
            UserProfileStore.load(for: "apple-user-1", userDefaults: userDefaults),
            profile
        )
        XCTAssertNil(UserProfileStore.load(for: "apple-user-2", userDefaults: userDefaults))
    }

    func testSaveIgnoresPlaceholderProfile() {
        UserProfileStore.save(.placeholder, for: "apple-user", userDefaults: userDefaults)

        XCTAssertNil(UserProfileStore.load(for: "apple-user", userDefaults: userDefaults))
    }

    func testClearRemovesOnlyMatchingUserProfile() {
        let firstProfile = UserProfile(
            nickname: "첫 유저",
            defaultImageName: "profileDefaultYellow",
            customImageData: nil
        )
        let secondProfile = UserProfile(
            nickname: "두 번째 유저",
            defaultImageName: "profileDefaultPurple",
            customImageData: nil
        )

        UserProfileStore.save(firstProfile, for: "apple-user-1", userDefaults: userDefaults)
        UserProfileStore.save(secondProfile, for: "apple-user-2", userDefaults: userDefaults)

        UserProfileStore.clear(for: "apple-user-1", userDefaults: userDefaults)

        XCTAssertNil(UserProfileStore.load(for: "apple-user-1", userDefaults: userDefaults))
        XCTAssertEqual(
            UserProfileStore.load(for: "apple-user-2", userDefaults: userDefaults),
            secondProfile
        )
    }

    func testMigratesValidLegacyProfileOnce() throws {
        let legacyProfile = UserProfile(
            nickname: "기존 유저",
            defaultImageName: "profileDefaultPink",
            customImageData: nil
        )
        let legacyData = try JSONEncoder().encode(legacyProfile)
        userDefaults.set(legacyData, forKey: "userProfile")

        UserProfileStore.migrateLegacyProfileIfNeeded(for: "apple-user", userDefaults: userDefaults)

        XCTAssertNil(userDefaults.data(forKey: "userProfile"))
        XCTAssertEqual(
            UserProfileStore.load(for: "apple-user", userDefaults: userDefaults),
            legacyProfile
        )

        UserProfileStore.migrateLegacyProfileIfNeeded(for: "apple-user", userDefaults: userDefaults)

        XCTAssertEqual(
            UserProfileStore.load(for: "apple-user", userDefaults: userDefaults),
            legacyProfile
        )
    }

    func testDoesNotMigrateInvalidLegacyProfile() {
        userDefaults.set(Data("invalid".utf8), forKey: "userProfile")

        UserProfileStore.migrateLegacyProfileIfNeeded(for: "apple-user", userDefaults: userDefaults)

        XCTAssertNotNil(userDefaults.data(forKey: "userProfile"))
        XCTAssertNil(UserProfileStore.load(for: "apple-user", userDefaults: userDefaults))
    }
}
