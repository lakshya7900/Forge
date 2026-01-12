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
    @EnvironmentObject private var projectStore: ProjectStore
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
    @StateObject private var store: ProjectStore

    init() {
        _store = StateObject(wrappedValue: {
            let demoOwner = ProjectMember(username: "preview-user", roleKey: "frontend")
            
            let s = ProjectStore(username: "preview-user")
            s.projects = [
                Project(
                    name: "Demo: Roadmate Planner 1",
                    description: "Seed project for UI iteration.",
                    members: [
                        demoOwner,
                        ProjectMember(username: "teammateA", roleKey: "frontend"),
                        ProjectMember(username: "teammateB", roleKey: "backend"),
                        ProjectMember(username: "teammateC", roleKey: "pm"),
                    ],
                    tasks: [
                        TaskItem(title: "Set up app shell + navigation", status: .done),
                        TaskItem(title: "Polish Task Card UI", status: .inProgress),
                        TaskItem(title: "Implement ProjectStore persistence", status: .inProgress),
                        TaskItem(title: "Define roadmap JSON schema", status: .backlog),
                        TaskItem(title: "Fix blocked state styling", status: .blocked),
                    ],
                    ownerMemberId: demoOwner.id
                ),
                Project(
                    name: "Demo: Roadmate Planner 2",
                    description: "Seed project for UI iteration.",
                    members: [
                        demoOwner
                    ],
                    tasks: [
                        TaskItem(title: "Draft onboarding", status: .backlog)
                    ],
                    ownerMemberId: demoOwner.id
                )
            ]
            return s
        }())
    }

    var body: some View {
        ProjectsListView()
            .environmentObject(store)
    }
}
