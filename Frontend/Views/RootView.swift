//
//  RootView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct RootView: View {
    @Environment(SessionState.self) private var session
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore

    @State private var showCreateProject = false
    @State private var showAlert = false
    
    @State private var projectService = ProjectService()
    private var projects: [Project] { projectStore.projects }

    var body: some View {
        NavigationSplitView {
            SidebarView(projects: projects)
                .navigationSplitViewColumnWidth(min: 185, ideal: 200, max: 500)
        } detail: {
            detailView
        }
        .task { await getProjects() }
        .toolbar {

            // Show "+" only when we’re in Projects section
            if isProjectsContext {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Project")
                }
            }
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectView { newProject in
                projectStore.upsert(newProject)
                appState.selection = .project(newProject.id)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selection {
        case .profile:
            ProfileView()

        case .allProjects, .none:
            AllProjectsGridView(
                projects: projects,
                onSelect: { id in appState.selection = .project(id) }
            )

        case .project(let id):
            if let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project)
                    .id(project.id)
            } else {
                EmptyStateView()
            }

        case .planner:
            EmptyStateView()
                .overlay(alignment: .topLeading) {
                    Text("AI Planner")
                        .padding(20)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var isProjectsContext: Bool {
        switch appState.selection {
        case .allProjects, .project(_):
            return true
        default:
            return false
        }
    }
    
    private func getProjects() async {
        guard let token = KeychainService.loadToken() else {
            print("Token error")
            return
        }
        
        do {
            let p = try await projectService.getProjects(token: token)
            projectStore.replaceAll(p)
        } catch {
            print("Error")
            return
        }
    }
}



#Preview {
    let session = SessionState()
    
    let demoOwner = ProjectMember(username: "preview-user", roleKey: "frontend")

    let appState = AppState()

    let demoProject1 = Project(
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
    )

    let demoProject2 = Project(
        id: UUID(),
        name: "Demo: Roadmate Planner 2",
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
    )

    let projectStore = ProjectStore.preview(projects: [demoProject1, demoProject2])

    RootView()
        .environment(session)
        .environment(appState)
        .environment(projectStore)
        .frame(width: 900, height: 500)
}

