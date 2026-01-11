//
//  ProjectMembersView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import SwiftUI

struct ProjectMembersView: View {
    @Binding var project: Project

    @State private var showAddMember = false
    @State private var deletingMemberId: UUID?

    @State private var searchText: String = ""
    @State private var selectedRoleFilter: String = "All" // "All" or roleKey

    @State private var showAddRole = false
    @State private var newRoleName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            controls

            if filteredMembers.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredMembers) { member in
                            MemberRow(
                                member: member,
                                roleOptions: roleOptions,
                                isOwner: isOwner(member),
                                onChangeRole: { newRoleKey in updateRole(memberId: member.id, roleKey: newRoleKey) },
                                onRequestAddRole: { showAddRole = true },
                                onDelete: isOwner(member) ? nil : { deletingMemberId = member.id }
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .sheet(isPresented: $showAddMember) {
            AddMemberView(
                roleOptions: roleOptions,
                onRequestAddRole: { showAddRole = true },
                onAdd: { username, roleKey in
                    addMember(username: username, roleKey: roleKey)
                }
            )
        }
        .confirmationDialog(
            "Remove member?",
            isPresented: Binding(
                get: { deletingMemberId != nil },
                set: { if !$0 { deletingMemberId = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let id = deletingMemberId { removeMember(id) }
                deletingMemberId = nil
            }
            Button("Cancel", role: .cancel) { deletingMemberId = nil }
        }
        .alert("Add Custom Role", isPresented: $showAddRole) {
            TextField("Role name (e.g., Designer, DevOps)", text: $newRoleName)

            Button("Add") { addCustomRole() }
            Button("Cancel", role: .cancel) { newRoleName = "" }
        } message: {
            Text("This role will appear in the role dropdown for all team members in this project.")
        }
    }

    // MARK: - UI

    private var header: some View {
        HStack {
            Label("Team", systemImage: "person.2")
                .font(.headline)

            Spacer()

            Button { showAddMember = true } label: {
                Label("Add Member", systemImage: "plus")
            }
        }
        .padding(.top, 2)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search members", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Picker("Role", selection: $selectedRoleFilter) {
                Text("All").tag("All")
                Divider()
                ForEach(roleOptions, id: \.key) { opt in
                    Text(opt.label).tag(opt.key)
                }
            }
            .frame(maxWidth: 240)

            Spacer()
        }
    }

    // MARK: - Role options
    private func isOwner(_ member: ProjectMember) -> Bool {
        member.id == project.ownerMemberId
    }

    private var roleOptions: [AddMemberView.RoleOption] {
        let predefined = ProjectRole.allCases.map {
            AddMemberView.RoleOption(key: $0.rawValue, label: $0.label)
        }
        let custom = project.customRoles.map {
            AddMemberView.RoleOption(key: $0, label: $0)
        }
        return predefined + custom
    }

    // MARK: - Filtering

    private var filteredMembers: [ProjectMember] {
        var list = project.members

        if selectedRoleFilter != "All" {
            list = list.filter { $0.roleKey == selectedRoleFilter }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.username.lowercased().contains(q) ||
                $0.displayRole.lowercased().contains(q)
            }
        }

        // owner first, then alphabetical
        list.sort { a, b in
            if isOwner(a) && !isOwner(b) { return true }
            if !isOwner(a) && isOwner(b) { return false }
            return a.username.lowercased() < b.username.lowercased()
        }

        return list
    }

    private var emptyText: String {
        if project.members.isEmpty { return "No members yet." }
        if !searchText.isEmpty { return "No results for “\(searchText)”." }
        return "No members match this role filter."
    }

    // MARK: - Mutations

    private func addMember(username: String, roleKey: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exists = project.members.contains { $0.username.lowercased() == trimmed.lowercased() }
        guard !exists else { return }

        project.members.append(ProjectMember(username: trimmed, roleKey: roleKey))
    }

    private func updateRole(memberId: UUID, roleKey: String) {
        guard let idx = project.members.firstIndex(where: { $0.id == memberId }) else { return }
        project.members[idx].roleKey = roleKey
    }

    private func removeMember(_ id: UUID) {
        if id == project.ownerMemberId { return }
        project.members.removeAll { $0.id == id }
    }

    private func addCustomRole() {
        let role = newRoleName.trimmingCharacters(in: .whitespacesAndNewlines)
        newRoleName = ""
        guard !role.isEmpty else { return }

        // Prevent duplicates (case-insensitive) and collisions with predefined keys
        let lower = role.lowercased()

        if ProjectRole.allCases.map({ $0.rawValue.lowercased() }).contains(lower) { return }
        if project.customRoles.map({ $0.lowercased() }).contains(lower) { return }

        project.customRoles.append(role)
        project.customRoles.sort { $0.lowercased() < $1.lowercased() }
    }
}
