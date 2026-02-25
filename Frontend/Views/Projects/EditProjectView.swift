//
//  EditProjectView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProjectStore.self) private var projectStore
    
    @State private var projectService = ProjectService()

    // Inputs
    @State private var name: String
    @State private var description: String

    let project: Project
    let onSave: (String, String) -> Void

    // UI state
    @State private var message: String? = nil
    @State private var isLoading = false
    @State private var shakeTrigger: Int = 0

    @FocusState private var focusedField: Field?
    enum Field { case name, description }

    init(project: Project, onSave: @escaping (String, String) -> Void) {
        self.project = project
        self.onSave = onSave
        
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description)
    }

    var body: some View {
        VStack(spacing: 14) {

            header

            contentCard
            
            footer
        }
        .padding(18)
        .frame(minWidth: 560, minHeight: 340)
        .onAppear { focusedField = .name }
        .animation(.snappy, value: message)
        .animation(.snappy, value: isLoading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit Project")
                    .font(.title2.weight(.semibold))

                Text("Update the name and description.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.6))
        )
    }

    // MARK: - Content

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Project name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g., Roadmate", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .disabled(isLoading)
                    .onSubmit { focusedField = .description }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(description.count)/280")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TextField("What is this project about?", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .description)
                    .disabled(isLoading)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shake(shakeTrigger, amount: 6, shakesPerUnit: 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isLoading)

            Spacer()

            VStack() {
                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .transition(.opacity)
                }

                Button {
                    Task { await updateProject() }
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                        Text(isLoading ? "Saving…" : "Save")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isLoading)
                .shake(shakeTrigger)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateProject() async {
        message = nil
        
        isLoading = true
        defer { isLoading = false }
        
        guard let token = KeychainService.loadToken() else {
            message = "Failed to save. Please try again later."
            shakeTrigger += 1
            return
        }
        
        do {
            let n = trimmedName
            let d = description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if n.isEmpty {
                message = "Project name can’t be empty."
                shakeTrigger += 1
                return
            }
            
            let dto = try await projectService.editProject(
                token: token,
                id: project.id,
                name: n,
                description: d
            )
            
            var updated = project
            updated.name = dto.name
            updated.description = dto.description
            
            onSave(updated.name, updated.description)
            projectStore.upsert(updated)
            
            dismiss()
        } catch {
            message = "Failed to save. Please try again later."
            shakeTrigger += 1
        }
    }
}

#Preview("Edit Project – Demo") {
    let owner = ProjectMember(username: "lakshya", roleKey: "owner")

    let project = Project(
        id: UUID(),
        name: "Roadmate",
        description: "Local AI dev planner for teams.",
        members: [owner],
        tasks: [TaskItem(id: UUID(), title: "Profile Polish", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 2)],
        ownerMemberId: owner.id
    )

    EditProjectView(project: project) { _, _ in
        // no-op
    }
    .frame(width: 600, height: 360)
    .padding(12)
}
