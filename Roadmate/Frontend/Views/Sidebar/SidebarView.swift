//
//  SidebarView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectStore: ProjectStore

    @State private var projectsExpanded: Bool = true

    var body: some View {
        List(selection: $appState.selection) {

            NavigationLink(value: AppState.Route.profile) {
                Label("Profile", systemImage: "person.crop.circle")
            }
            

            NavigationLink(value: AppState.Route.planner) {
                Label("AI Planner", systemImage: "sparkles")
            }

            Section {
                NavigationLink(value: AppState.Route.allProjects) {
                    Label("All Projects", systemImage: "square.grid.2x2")
                }

                ForEach(projectStore.projects) { project in
                    NavigationLink(value: AppState.Route.project(project.id)) {
                        Label(project.name, systemImage: "folder")
                            .lineLimit(1)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            delete(project.id)
                        }
                    }
                }
            } header: {
                Text("Projects")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.gray)
            }

        }
        .listStyle(.sidebar)
        .navigationTitle("Roadmate")
    }

    private func delete(_ id: UUID) {
        projectStore.delete(id)
        if appState.selection == .project(id) {
            appState.selection = .allProjects
        }
    }
}

#Preview("Merged Sidebar") {
    MergedSidebarPreviewHost()
}

private struct MergedSidebarPreviewHost: View {
    @StateObject private var appState = AppState()
    @StateObject private var store: ProjectStore

    init() {
        let owner = ProjectMember(username: "preview-user", roleKey: "frontend")

        _store = StateObject(wrappedValue: {
            let s = ProjectStore(username: "preview-user")
            s.projects = [
                Project(name: "Demo One", description: "", members: [owner], tasks: [], ownerMemberId: owner.id),
                Project(name: "Demo Two", description: "", members: [owner], tasks: [], ownerMemberId: owner.id)
            ]
            return s
        }())
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(appState)
                .environmentObject(store)
        } detail: {
            Text("Detail")
        }
    }
}

