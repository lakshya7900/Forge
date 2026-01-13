import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile

    private let fileURL: URL?
    private let persistenceEnabled: Bool

    // MARK: - NORMAL (app runtime)
    init(username: String) {
        self.persistenceEnabled = true

        let safe = username.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]+",
            with: "-",
            options: .regularExpression
        )

        let url = Self.makeFileURL(filename: "profile-\(safe).json")
        self.fileURL = url

        if let loaded = Self.load(from: url) {
            self.profile = loaded
        } else {
            // Create default profile
            self.profile = UserProfile.defaultProfile(for: username)
            save()
        }
    }

    // MARK: - PREVIEW (no disk)
    static func preview(profile: UserProfile) -> ProfileStore {
        let store = ProfileStore(persistenceEnabled: false)
        store.profile = profile
        return store
    }

    private init(persistenceEnabled: Bool) {
        self.persistenceEnabled = persistenceEnabled
        self.fileURL = nil
        self.profile = UserProfile.defaultProfile(for: "preview-user")
    }

    func save() {
        guard persistenceEnabled, let fileURL else { return }
        Self.save(profile, to: fileURL)
    }

    // MARK: - Helpers
    private static func makeFileURL(filename: String) -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory

        let folder = base.appendingPathComponent("Roadmate", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        return folder.appendingPathComponent(filename)
    }

    private static func load(from url: URL) -> UserProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    private static func save(_ profile: UserProfile, to url: URL) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
