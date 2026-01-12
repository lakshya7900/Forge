//
//  ProjectDetailView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var projectStore: ProjectStore
    @State private var project: Project

    init(project: Project) {
        _project = State(initialValue: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            TabView {
                ProjectOverviewView(project: $project)
                    .tabItem { Label("Overview", systemImage: "doc.text") }

                ProjectBoardView(project: $project)
                    .tabItem { Label("Board", systemImage: "square.grid.3x1.folder.badge.plus") }

                ProjectMembersView(project: $project)
                    .tabItem { Label("Team", systemImage: "person.2") }
            }
            .padding(12)
        }
        .onChange(of: project) { _, newValue in
            projectStore.upsert(newValue)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.title2)
                .fontWeight(.semibold)

            if !project.description.isEmpty {
                Text(project.description)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

#Preview("Project Detail – Demo (Simple)") {
    ProjectDetailPreviewHost()
}

private struct ProjectDetailPreviewHost: View {
    @StateObject private var store: ProjectStore
    private let demo: Project

    init() {
        let demoOwner = ProjectMember(username: "preview-user", roleKey: "owner")
        
        let demo = Project(
            name: "Demo: Roadmate Planner",
            description: "Seed project for UI iteration.",
            members: [
                demoOwner,
                ProjectMember(username: "teammateA", roleKey: "frontend"),
                ProjectMember(username: "teammateB", roleKey: "backend"),
            ],
            tasks: [
                TaskItem(title: "Set up app shell + navigation", status: .done, ownerUsername: "preview-user", difficulty: 2),
                TaskItem(title: "Polish Task Card UI", status: .inProgress, ownerUsername: "teammateA", difficulty: 3),
                TaskItem(title: "Define roadmap JSON schema", status: .backlog, ownerUsername: "teammateB", difficulty: 2),
            ],
            ownerMemberId: demoOwner.id
        )

        self.demo = demo

        _store = StateObject(wrappedValue: {
            let s = ProjectStore(username: "preview-user")
            s.projects = [demo]
            return s
        }())
    }

    var body: some View {
        NavigationStack {
            ProjectDetailView(project: demo)
                .environmentObject(store)
                .frame(width: 800, height: 450)
        }
    }
}
