//
//  AddCustomRolesView.swift
//  Forge
//
//  Created by Lakshya Agarwal on 3/8/26.
//

import SwiftUI

struct AddCustomRolesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    
    @State private var projectsService = ProjectService()
    
    @State private var newRoleName: String = ""
    @State private var newRoles:[String] = []
    
    // UI state
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""
    @State private var isLoading = false
    @State private var shakeTrigger: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Roles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                VStack(alignment: .leading) {
                    TextField("Role name (e.g., Designer, DevOps)", text: $newRoleName) {
                        let trimmed = newRoleName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let lower = trimmed.lowercased()
                            let alreadyInNew = newRoles.map { $0.lowercased() }.contains(lower)
                            let alreadyInProject = project.customRoles.map { $0.lowercased() }.contains(lower)
                            let alreadyPredefined = ProjectRole.allCases.map { $0.rawValue.lowercased() }.contains(lower)

                            if alreadyInNew || alreadyInProject || alreadyPredefined {
                                errorMessage = "Role already added."
                                successMessage = ""
                                shakeTrigger += 1
                            } else {
                                newRoles.append(trimmed)
                                errorMessage = ""
                            }
                        } else {
                            errorMessage = "Role name is empty!"
                            successMessage = ""
                            shakeTrigger += 1
                        }
                        newRoleName = ""
                    }
                    
                    if newRoles.count != 0 {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(newRoles, id: \.self) { role in
                                HStack(spacing: 5) {
                                    Text(role)
                                        .foregroundStyle(.white)
                                        .padding(.leading, 5)
                                    Button {
                                        newRoles.removeAll(where: { $0 == role })
                                    } label: {
                                        Image(systemName: "xmark")
                                            .controlSize(.small)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(5)
                                }
                                .background(.tint)
                                .cornerRadius(5)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            VStack(alignment: .trailing) {
                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.bottom, 5)
                }
                
                if !successMessage.isEmpty {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(.bottom, 5)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button(action: {
                        Task { await addCustomRole() }
                    }, label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            }
                            Text("Add")
                        }
                    })
                    .disabled(isLoading)
                    .shake(shakeTrigger)
                    .animation(.snappy, value: isLoading)
                    .background(Color.accentColor)
                    .cornerRadius(7)
                }
            }
        }
        .animation(.snappy, value: errorMessage.isEmpty && successMessage.isEmpty)
    }
    
    private func addCustomRole() async {
        successMessage = ""
        errorMessage = ""
        
        isLoading = true
        defer { isLoading = false }
        
        guard let token = KeychainService.loadToken() else {
            errorMessage = "Missing token. Please log in again."
            successMessage = ""
            shakeTrigger += 1
            return
        }
        
        if newRoles.isEmpty {
            successMessage = ""
            errorMessage = "No custom roles to add."
            shakeTrigger += 1
            return
        }
        
        do {
            try await projectsService.addCustomRoles(token: token, id: project.id, customRoles: newRoles)
            project.customRoles.append(contentsOf: newRoles)
            project.customRoles = Array(Set(project.customRoles)).sorted { $0.lowercased() < $1.lowercased() }
            
            errorMessage = ""
            successMessage = "Added custom roles"
            newRoles.removeAll()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to add roles. Please try again."
            successMessage = ""
            shakeTrigger += 1
        }
    }
}

#Preview {
    // Build preview data without cross-referencing preview state in initializers
    let owner = ProjectMember(username: "preview-user", roleKey: "owner")
    @State var project = Project(
        id: UUID(),
        name: "Demo: Roadmate Planner",
        description: "Seed project for UI iteration.",
        members: [
            owner,
            ProjectMember(username: "teammateA", roleKey: "frontend"),
            ProjectMember(username: "teammateB", roleKey: "backend"),
        ],
        tasks: [
            TaskItem(id: UUID(), title: "Setup shell + navigation", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 2),
            TaskItem(id: UUID(), title: "Profile Polish", details: "", status: .done, difficulty: 2, createdAt: Date(), sortIndex: 1),
            TaskItem(id: UUID(), title: "Define roadmap schema", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 3),
        ],
        ownerMemberId: owner.id
    )

    return AddCustomRolesView(project: $project)
        .frame(minHeight: 200)
        .padding()
}

