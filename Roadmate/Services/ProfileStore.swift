import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile

    private let fileURL: URL

    init(username: String) {
        // File name based on username so multiple test accounts don’t overwrite each other
        let safe = username.replacingOccurrences(of: "[^a-zA-Z0-9_-]+", with: "-", options: .regularExpression)
        self.fileURL = ProfileStore.makeFileURL(filename: "profile-\(safe).json")

        if let loaded = ProfileStore.load(from: fileURL) {
            self.profile = loaded
        } else {
            self.profile = UserProfile(
                displayName: username,
                headline: "",
                skills: []
            )
            ProfileStore.save(self.profile, to: fileURL)
        }
    }

    func save() {
        ProfileStore.save(profile, to: fileURL)
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
