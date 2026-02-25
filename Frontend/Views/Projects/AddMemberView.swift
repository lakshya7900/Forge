//
//  AddMemberView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct AddMemberView: View {
    private static let addCustomRoleKey = "__add_custom__"
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID
    let roleOptions: [RoleOption]
    let onRequestAddRole: () -> Void
    let onInviteSent: (_ username: String, _ roleKey: String, _ inviteId: UUID) -> Void
    
    @State private var membersService = MembersService()

    @State private var username = ""
    @State private var selectedRoleKey: String = ProjectRole.fullstack.rawValue
    
    // Search username
    @State private var results: [UserMini] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var lastQuery: String = ""
    
    // UI state
    @State private var message: String = ""
    @State private var isLoading = false
    @State private var shakeTrigger: Int = 0

    struct RoleOption: Identifiable {
        var id: String { key }
        let key: String
        let label: String
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "at")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        TextField("Username", text: $username)
                            .textFieldStyle(.plain)
                            .onChange(of: username) { _, newValue in
                                scheduleSearch(newValue)
                            }
                    }
                    
                    if !results.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(results) { u in
                                Button {
                                    username = u.username
                                    results = []
                                    lastQuery = u.username
                                    searchTask?.cancel()
                                } label: {
                                    HStack {
                                    Text(u.username)
                                    Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                }
                                .buttonStyle(.plain)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Role")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Picker(selection: $selectedRoleKey) {
                            ForEach(roleOptions) { opt in
                                Text(opt.label).tag(opt.key)
                            }
                            Divider()
                            Text("Add Custom Role…").tag(Self.addCustomRoleKey)
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        )
                        .onChange(of: selectedRoleKey) { _, newValue in
                            if newValue == Self.addCustomRoleKey {
                                // revert to a safe default and open add-role UI
                                selectedRoleKey = roleOptions.first?.key ?? ProjectRole.fullstack.rawValue
                                onRequestAddRole()
                            }
                        }
                    }
                }
            }

            footerButtons
        }
        .padding(20)
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    
    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Team Member")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Invite by username")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Spacer()
        }
    }

    private var footerButtons: some View {
        VStack(alignment: .trailing) {
            if !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            
            HStack(spacing: 10) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    Task { await sendInvite() }
                }, label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                        Text("Send Invite")
                    }
                })
                .disabled(isLoading)
                .shake(shakeTrigger)
                .animation(.snappy, value: isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.top, 2)
        .animation(.snappy, value: message)
    }
    
    private func scheduleSearch(_ text: String) {
        message = ""
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // clear if too short
        guard q.count >= 2 else {
            results = []
            isLoading = false
            searchTask?.cancel()
            return
        }

        // cancel previous debounce/task
        searchTask?.cancel()

        // start a new debounced task
        searchTask = Task {
            // debounce delay
            try? await Task.sleep(nanoseconds: 300_000_000)

            // if cancelled, stop
            guard !Task.isCancelled else { return }

            // don’t re-run same query
            if q.lowercased() == lastQuery.lowercased() { return }
            lastQuery = q

            await runSearch(q)
        }
    }

    @MainActor
    private func runSearch(_ q: String) async {
        guard let token = KeychainService.loadToken() else {
            shakeTrigger += 1
            message = "Missing token. Please log in again."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let found = try await membersService.searchUsers(token: token, query: q)

            // Only apply if field still matches this query (prevents stale results)
            let current = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard current.lowercased() == q.lowercased() else { return }

            results = found
        } catch {
            // keep it quiet; search failures shouldn’t be too loud
            results = []
        }
    }
    
    @MainActor
    private func sendInvite() async {
        results = []
        
        guard let token = KeychainService.loadToken() else {
            shakeTrigger += 1
            message = "Missing token. Please log in again."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUsername.isEmpty else {
                shakeTrigger += 1
                message = "Username is empty"
                return
            }
            
            let invite = try await membersService.sendInvite(token: token, projectId: projectId, username: trimmedUsername, roleKey: selectedRoleKey)
            
            guard let inviteID = UUID(uuidString: invite.id) else { return }
            
            onInviteSent(trimmedUsername, selectedRoleKey, inviteID)
            dismiss()
        } catch let error as MembersError {
            switch error {
            case .memberNotFound:
                message = "User not found!"
            case .inviteAlreadyExists:
                message = "Member already invited."
            case .noAccess:
                message = "You don't have access to this project."
            case .serverError:
                message = "Server error. Please try again."
            case .inviteNotFound:
                message = "Invitation not found refresh the project."
            }
            
            shakeTrigger += 1
        } catch {
            // Fallback for unexpected errors
            message = "Server error. Please try again."
            shakeTrigger += 1
        }
    }
}

#Preview("Add Member") {
    let mockRoles: [AddMemberView.RoleOption] = [
        .init(key: ProjectRole.fullstack.rawValue, label: "Full‑stack"),
        .init(key: "ios", label: "iOS Engineer"),
        .init(key: "backend", label: "Backend Engineer")
    ]
    AddMemberView(
        projectId: UUID(),
        roleOptions: mockRoles,
        onRequestAddRole: {},
        onInviteSent: { username, roleKey, inviteId in
            print("Preview add:", username, roleKey, inviteId)
        }
    )
}

