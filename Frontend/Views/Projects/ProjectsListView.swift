//
//  ProjectsListView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

private enum ProjectsRoute: Hashable {
    case all
    case project(UUID)
}

struct ProjectsListView: View {
    @Environment(ProjectStore.self) private var projectStore
    @State private var selection: ProjectsRoute? = .all
    @State private var showCreate = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // All Projects (like “Albums” smart group)
                NavigationLink(value: ProjectsRoute.all) {
                    Label("All Projects", systemImage: "square.grid.2x2")
                }

                Section("Projects") {
                    ForEach(projectStore.projects) { project in
                        NavigationLink(value: ProjectsRoute.project(project.id)) {
                            Text(project.name)
                                .lineLimit(1)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                delete(project.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Project")
                }
            }
        } detail: {
            switch selection {
            case .all, .none:
                AllProjectsGridView(
                    projects: projectStore.projects,
                    onSelect: { id in selection = .project(id) }
                )

            case .project(let id):
                if let project = projectStore.projects.first(where: { $0.id == id }) {
                    ProjectDetailView(project: project)
                } else {
                    EmptyStateView()
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateProjectView { newProject in
                projectStore.upsert(newProject)
                selection = .project(newProject.id)
            }
            .frame(minWidth: 520, minHeight: 420)
        }
    }
    
    private func delete(_ id: UUID) {
        projectStore.delete(id)
        if selection == .project(id) {
            selection = .all
        }
    }

}


#Preview("Projects – Demo Data", traits: .fixedLayout(width: 800, height: 450)) {
    ProjectsListPreviewHost()
}

private struct ProjectsListPreviewHost: View {
    @State private var store: ProjectStore

    init() {
        _store = State(wrappedValue: {
            let demoOwner = ProjectMember(username: "preview-user", roleKey: "frontend")
            
            let s = ProjectStore(username: "preview-user")
            s.projects = [
                Project(
                    id: UUID(),
                    name: "Demo: Roadmate Planner 1",
                    description: "Seed project for UI iteration.",
                    members: [
                        demoOwner,
                        ProjectMember(username: "teammateA", roleKey: "frontend"),
                        ProjectMember(username: "teammateB", roleKey: "backend"),
                        ProjectMember(username: "teammateC", roleKey: "pm"),
                    ],
                    tasks: [
                        TaskItem(id: UUID(), title: "Set up app shell + navigation", details: "", status: .done, difficulty: 4, createdAt: Date(), sortIndex: 0),
                        TaskItem(id: UUID(), title: "Polish Task Card UI",  details: "", status: .inProgress, difficulty: 1, createdAt: Date(), sortIndex: 1),
                        TaskItem(id: UUID(), title: "Implement ProjectStore persistence",  details: "", status: .inProgress, difficulty: 4, createdAt: Date(), sortIndex: 0),
                        TaskItem(id: UUID(), title: "Define roadmap JSON schema",  details: "", status: .backlog, difficulty: 4, createdAt: Date(), sortIndex: 0),
                        TaskItem(id: UUID(), title: "Fix blocked state styling",  details: "", status: .backlog, difficulty: 4, createdAt: Date(), sortIndex: 1)
                    ],
                    ownerMemberId: demoOwner.id
                ),
                Project(
                    id: UUID(),
                    name: "Demo: Roadmate Planner 2",
                    description: "Seed project for UI iteration.",
                    members: [
                        demoOwner
                    ],
                    tasks: [
                        TaskItem(id: UUID(), title: "Fix blocked state styling",  details: "", status: .backlog, difficulty: 4, createdAt: Date(), sortIndex: 1)
                    ],
                    ownerMemberId: demoOwner.id
                )
            ]
            return s
        }())
    }

    var body: some View {
        ProjectsListView()
            .environment(store)
    }
}
