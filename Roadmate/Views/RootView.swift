//
//  RootView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var showCreateProject = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 185, ideal: 200, max: 500)
        } detail: {
            detailView
        }
        .toolbar {
            if appState.selection == .profile {
                ToolbarItem(placement: .automatic) {
                    Button("Log Out") { session.logout() }
                }
            }

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
            .frame(minWidth: 520, minHeight: 420)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selection {
        case .profile:
            ProfileView()

        case .allProjects, .none:
            AllProjectsGridView(
                projects: projectStore.projects,
                onSelect: { id in appState.selection = .project(id) }
            )

        case .project(let id):
            if let project = projectStore.projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project)
            } else {
                EmptyStateView()
            }

        case .planner:
            EmptyStateView()
                .overlay(alignment: .topLeading) {
                    Text("AI Planner (Step 5)")
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
}



#Preview {
    let session = SessionState()
    let _ = session.login(username: "preview-user")
    
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
            TaskItem(title: "Set up app shell + navigation", status: .done),
            TaskItem(title: "Polish Task Card UI", status: .inProgress),
            TaskItem(title: "Implement ProjectStore persistence", status: .inProgress),
            TaskItem(title: "Define roadmap JSON schema", status: .backlog),
            TaskItem(title: "Fix blocked state styling", status: .blocked),
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
            TaskItem(title: "Set up app shell + navigation", status: .done),
            TaskItem(title: "Polish Task Card UI", status: .inProgress),
            TaskItem(title: "Implement ProjectStore persistence", status: .inProgress),
            TaskItem(title: "Define roadmap JSON schema", status: .backlog),
            TaskItem(title: "Fix blocked state styling", status: .blocked),
        ],
        ownerMemberId: demoOwner.id
    )

    let projectStore = ProjectStore.preview(projects: [demoProject1, demoProject2])

    let demoSkill = Skill(name: "Swift", proficiency: 8)
    let demoEducation = Education(school: "Virginia Tech", degree: "Bachelor's", major: "Computer Science", startyear: 2024, endyear: 2028)
    let profileStore = ProfileStore.preview(profile: UserProfile(
        username: "user1234",
        name: "Preview User",
        headline: "SwiftUI • macOS",
        bio: "HIIIII",
        skills: [demoSkill],
        education: [demoEducation]
    ))

    RootView()
        .environmentObject(session)
        .environmentObject(appState)
        .environmentObject(projectStore)
        .environmentObject(profileStore)
        .frame(width: 600, height: 340)
}
