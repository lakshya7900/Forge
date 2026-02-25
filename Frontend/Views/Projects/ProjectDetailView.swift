//
//  ProjectDetailView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct ProjectDetailView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectService = ProjectService()
    @State private var project: Project
    
    @State private var showEditProject = false
    @State private var showAlert = false

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
        .sheet(isPresented: $showEditProject) {
            EditProjectView(
                project: project,
                onSave: { newName, newDesc in
                    let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let d = newDesc.trimmingCharacters(in: .whitespacesAndNewlines)

                    project.name = n
                    project.description = d

                    projectStore.upsert(project)

                    showEditProject = false
                }
            )
        }
    }

    private var header: some View {
        HStack() {
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
            
            Spacer()
            
            HStack() {
                Button {
                    showEditProject = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    showAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .alert("Delete this project?", isPresented: $showAlert, actions: {
                    Button("Cancel", role: .cancel) {}
                    Button(role: .destructive) {
                        Task{ await deleteProject() }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }, message: {
                    Text("This can't be undone")
                })
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(16)
        }
    }
    
    private func deleteProject() async {
        guard let token = KeychainService.loadToken() else {
            return
        }

        do {
            try await projectService.deleteProject(token: token, id: project.id)
            projectStore.delete(project.id)
            dismiss()
        } catch {
            return
        }
    }
}


#Preview("Project Detail – Demo (Simple)") {
    ProjectDetailPreviewHost()
}

private struct ProjectDetailPreviewHost: View {
    @State private var store: ProjectStore
    private let demo: Project

    init() {
        let demoOwner = ProjectMember(username: "preview-user", roleKey: "owner")
        
        let demo = Project(
            id: UUID(),
            name: "Demo: Roadmate Planner",
            description: "Seed project for UI iteration.",
            members: [
                demoOwner,
                ProjectMember(username: "teammateA", roleKey: "frontend"),
                ProjectMember(username: "teammateB", roleKey: "backend"),
            ],
            tasks: [
                TaskItem(id: UUID(), title: "Setup shell + navigation", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 2),
                TaskItem(id: UUID(), title: "Profile Polish", details: "", status: .done, difficulty: 2, createdAt: Date(), sortIndex: 1),
                TaskItem(id: UUID(), title: "Define roadmap schema", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 3),
            ],
            ownerMemberId: demoOwner.id
        )

        self.demo = demo

        _store = State(wrappedValue: {
            let s = ProjectStore(username: "preview-user")
            s.projects = [demo]
            return s
        }())
    }

    var body: some View {
        NavigationStack {
            ProjectDetailView(project: demo)
                .environment(store)
                .frame(width: 800, height: 450)
        }
    }
}
