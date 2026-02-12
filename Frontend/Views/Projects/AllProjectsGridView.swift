//
//  AllProjectsGridView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct AllProjectsGridView: View {
    @Environment(ProjectStore.self) private var projectStore

    let projects: [Project]
    let onSelect: (UUID) -> Void
    
    @State private var projectService = ProjectService()

    @State private var editingProjectId: UUID?
    @State private var deletingProjectId: UUID?

    private let cols = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("All Projects")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 6)

                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(sortedProjects) { project in
                        ProjectTile(
                            project: project,
                            onPin: { Task { await togglePin(project.id) }},
                            onEdit: { editingProjectId = project.id },
                            onDelete: { deletingProjectId = project.id }
                        )
                        .onTapGesture { onSelect(project.id) }
                    }
                }

                if projects.isEmpty {
                    Text("No projects yet. Click + to create one.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
            }
            .padding(20)
        }
        // Edit sheet
        .sheet(
            isPresented: Binding(
                get: { editingProjectId != nil },
                set: { if !$0 { editingProjectId = nil } }
            )
        ) {
            if let id = editingProjectId, let project = projects.first(where: { $0.id == id }) {
                EditProjectView(project: project) { newName, newDesc in
                    var updated = project
                    updated.name = newName
                    updated.description = newDesc
                    projectStore.upsert(updated)
                }
            } else {
                // Fallback in case the project can't be found
                Text("Project not found")
                    .padding()
            }
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete project?",
            isPresented: Binding(
                get: { deletingProjectId != nil },
                set: { if !$0 { deletingProjectId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = deletingProjectId {
                    projectStore.delete(id)
                }
                deletingProjectId = nil
            }
            Button("Cancel", role: .cancel) {
                deletingProjectId = nil
            }
        } message: {
            Text("This will remove the project from your local storage.")
        }
    }

    private var sortedProjects: [Project] {
        projects.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private func togglePin(_ id: UUID) async {
        guard let token = KeychainService.loadToken() else { return }
            guard let current = projectStore.projects.first(where: { $0.id == id }) else { return }

            // optimistic update
            var updated = current
            updated.isPinned.toggle()
            projectStore.upsert(updated)

            do {
                try await projectService.pinProject(token: token, id: id, pin: updated.isPinned)
            } catch {
                // revert if backend fails
                projectStore.upsert(current)
                // optionally show UI message/toast
                // complaint = "Failed to update pin"
            }
    }
}

