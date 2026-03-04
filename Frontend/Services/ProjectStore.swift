//
//  ProjectStore.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import Foundation
import SwiftUI
import Combine

@MainActor
@Observable final class ProjectStore {
    // Source of truth for UI (cached)
    var projects: [Project] = []

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

        let url = Self.makeFileURL(filename: "projects-\(safe).json")
        self.fileURL = url

        if let loaded = Self.load(from: url) {
            self.projects = loaded
        } else {
            self.projects = []
            save()
        }
    }

    // MARK: - PREVIEW (no disk)
    static func preview(projects: [Project] = []) -> ProjectStore {
        let store = ProjectStore(persistenceEnabled: false)
        store.projects = projects
        return store
    }

    private init(persistenceEnabled: Bool) {
        self.persistenceEnabled = persistenceEnabled
        self.fileURL = nil
        self.projects = []
    }

    // MARK: - Persistence
    func save() {
        guard persistenceEnabled, let fileURL else { return }
        Self.save(projects, to: fileURL)
    }

    // MARK: - List management (backend -> cache)
    /// Replace local cache with backend list
    func replaceAll(_ newProjects: [Project]) {
        projects = newProjects
        save()
    }

    /// Insert or update a project (used after create/edit APIs)
    func upsert(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            // newest first (matches your current style)
            projects.insert(project, at: 0)
        }
        save()
    }

    /// Delete a project (used after delete API)
    func delete(_ projectId: UUID) {
        projects.removeAll { $0.id == projectId }
        save()
    }

    // MARK: - Future: local-only patches after backend success
    /// When you add members API later, you’ll call this with the returned updated project.
    func updateMembers(projectId: UUID, members: [ProjectMember]) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[idx].members = members
        save()
    }

    /// When you add tasks API later, you’ll call this with the returned updated tasks.
    func updateTasks(projectId: UUID, tasks: [TaskItem]) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[idx].tasks = tasks
        save()
    }

    // MARK: - File helpers
    private static func makeFileURL(filename: String) -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory

        let folder = base.appendingPathComponent("Forge", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(filename)
    }

    private static func load(from url: URL) -> [Project]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Project].self, from: data)
    }

    private static func save(_ projects: [Project], to url: URL) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
