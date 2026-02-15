//
//  ProjectMembersView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import SwiftUI

struct ProjectMembersView: View {
    @Binding var project: Project
    
    @State private var membersService = MembersService()

    @State private var showAddMember = false
    @State private var deletingMemberId: UUID?

    @State private var searchText: String = ""
    @State private var selectedRoleFilter: String = "All" // "All" or roleKey

    @State private var showAddRole = false
    @State private var newRoleName = ""
    
    // Invitations (local UI state for now)
    @State private var pendingInvites: [ProjectInvite] = []
    @State private var declinedInvites: [ProjectInvite] = []

    struct ProjectInvite: Identifiable, Equatable {
        let id: UUID
        let username: String
        let roleKey: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            controls
            
            ScrollView {
                VStack(spacing: 10) {
                    // Invitations
                    if !pendingInvites.isEmpty {
                        inviteSection(
                            title: "Pending invites",
                            titleColor: Color.blue,
                            subtitle: "Waiting for the user to accept",
                            invites: pendingInvites,
                            actionTitle: "Cancel",
                            actionRole: .destructive,
                            action: cancelInvite
                        )
                    }

                    if !declinedInvites.isEmpty {
                        inviteSection(
                            title: "Declined invites",
                            titleColor: Color.red,
                            subtitle: "You can remove these entries",
                            invites: declinedInvites,
                            actionTitle: "Delete",
                            actionRole: .destructive,
                            action: deleteDeclinedInvite
                        )
                    }
                    
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

            Spacer(minLength: 0)
        }
        .padding(10)
        .task { await getInvites() }
        .sheet(isPresented: $showAddMember) {
            AddMemberView(
                projectId: project.id,
                roleOptions: roleOptions,
                onRequestAddRole: { showAddRole = true },
                onInviteSent: { username, roleKey in
                    addPendingInvite(username: username, roleKey: roleKey)
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

    // MARK: - Invite
    private func inviteSection(
        title: String,
        titleColor: Color,
        subtitle: String,
        invites: [ProjectInvite],
        actionTitle: String,
        actionRole: ButtonRole? = nil,
        action: @escaping (ProjectInvite) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(titleColor)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(invites) { inv in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inv.username)
                                .font(.subheadline.weight(.semibold))
                            Text(displayRoleLabel(inv.roleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: actionRole) {
                            action(inv)
                        } label: {
                            Text(actionTitle)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.top, 6)
    }
    
    private func getInvites() async {
        guard let token = KeychainService.loadToken() else {
            print("Token error")
            return
        }

        do {
            // Expected to be implemented in MembersService:
            // getProjectInvites(token:projectId:) -> ProjectInvitesResponse
            let resp = try await membersService.getProjectInvites(token: token, projectId: project.id)

            // Map backend invites into local UI models.
            let pending: [ProjectInvite] = resp.pending.compactMap { inv in
                guard let uuid = UUID(uuidString: inv.id.lowercased()) else { return nil }
                let username = inv.invitee_username.trimmingCharacters(in: .whitespacesAndNewlines)
                return ProjectInvite(id: uuid, username: username, roleKey: inv.role_key)
            }

            let declined: [ProjectInvite] = resp.declined.compactMap { inv in
                guard let uuid = UUID(uuidString: inv.id.lowercased()) else { return nil }
                let username = inv.invitee_username.trimmingCharacters(in: .whitespacesAndNewlines)
                return ProjectInvite(id: uuid, username: username, roleKey: inv.role_key)
            }
            let acceptedMembers: [ProjectMember] = resp.accepted.compactMap { inv in
                let uname = inv.invitee_username.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !uname.isEmpty else { return nil }

                // Require a valid invitee_id UUID for consistency.
                guard let memberUUID = UUID(uuidString: inv.invitee_id.lowercased()) else { return nil }
                return ProjectMember(id: memberUUID, username: uname, roleKey: inv.role_key)
            }


            // Keep lists sorted for stable UI.
            let pendingSorted = pending.sorted { $0.username.lowercased() < $1.username.lowercased() }
            let declinedSorted = declined.sorted { $0.username.lowercased() < $1.username.lowercased() }

            await MainActor.run {
                // Upsert accepted members into the project member list
                for m in acceptedMembers {
                    if let idx = project.members.firstIndex(where: { $0.username.lowercased() == m.username.lowercased() }) {
                        project.members[idx].roleKey = m.roleKey
                    } else {
                        project.members.append(m)
                    }
                }
                
                self.pendingInvites = pendingSorted
                self.declinedInvites = declinedSorted
            }
        } catch {
            // Non-fatal: just log for now.
            print("getInvites failed:", error)
        }
    }

    private func displayRoleLabel(_ roleKey: String) -> String {
        if let predefined = ProjectRole.allCases.first(where: { $0.rawValue == roleKey }) {
            return predefined.label
        }
        return roleKey
    }

    
    // MARK: - Role options
    private func isOwner(_ member: ProjectMember) -> Bool {
        return member.id == project.ownerMemberId
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

    private func addPendingInvite(username: String, roleKey: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // If already a member, do nothing
        if project.members.contains(where: { $0.username.lowercased() == trimmed.lowercased() }) {
            return
        }

        // If already pending/declined, do nothing
        if pendingInvites.contains(where: { $0.username.lowercased() == trimmed.lowercased() }) { return }
        if declinedInvites.contains(where: { $0.username.lowercased() == trimmed.lowercased() }) { return }

        pendingInvites.append(ProjectInvite(id: UUID(), username: trimmed, roleKey: roleKey))
        pendingInvites.sort { $0.username.lowercased() < $1.username.lowercased() }
    }

    private func cancelInvite(_ invite: ProjectInvite) {
        Task {
            guard let token = KeychainService.loadToken() else { return }
            do {
                try await membersService.cancelInvite(token: token, inviteId: invite.id)
                await MainActor.run {
                    pendingInvites.removeAll { $0.id == invite.id }
                }
            } catch {
                print("cancelInvite failed:", error)
            }
        }
    }

    private func deleteDeclinedInvite(_ invite: ProjectInvite) {
        Task {
            guard let token = KeychainService.loadToken() else { return }
            do {
                try await membersService.deleteInvite(token: token, inviteId: invite.id)
                await MainActor.run {
                    declinedInvites.removeAll { $0.id == invite.id }
                }
            } catch {
                print("deleteDeclinedInvite failed:", error)
            }
        }
    }

    // Call this when an invite is accepted (e.g. after a backend refresh)
    private func acceptInvite(username: String, roleKey: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pendingInvites.removeAll { $0.username.lowercased() == trimmed.lowercased() }
        declinedInvites.removeAll { $0.username.lowercased() == trimmed.lowercased() }
        
        // Upsert into members so it appears in filteredMembers immediately.
        if let idx = project.members.firstIndex(where: { $0.username.lowercased() == trimmed.lowercased() }) {
            project.members[idx].roleKey = roleKey
        } else {
            project.members.append(ProjectMember(username: trimmed, roleKey: roleKey))
        }
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
