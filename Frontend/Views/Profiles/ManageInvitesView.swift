//
//  ManageInvitesView.swift
//  Forge
//
//  Created by Lakshya Agarwal on 2/23/26.
//

import SwiftUI

struct ManageInvitesView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var invitations: [Invitations]
    @Binding var error: String?
    @Binding var isLoadingInvitations: Bool
    
    let onAccept: (Project) -> Void
    let onReload: () async -> Void
    
    @State private var profileService = ProfileService()
    
    // UI state
    @State private var message: String = ""
    @State private var shakeTrigger: Int = 0
    
    @State private var loadingAcceptIds: Set<UUID> = []
    @State private var loadingDeclineIds: Set<UUID> = []
    
    var body: some View {
        if isLoadingInvitations {
            ProgressView()
        } else if error != nil {
            VStack(spacing: 10) {
                Text(error ?? "").foregroundStyle(.red)
                Button("Retry") { Task { await onReload() } }
                    .buttonStyle(.bordered)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header

                if invitations.isEmpty {
                    ContentUnavailableView("No Invitations", systemImage: "bell", description: Text("You’re all caught up."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(invitations) { inv in
                                invitationRow(inv, showActions: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Invitations")
                        .font(.title2.weight(.semibold))

                    Text("Accept or decline project invites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -2)
                }

                Spacer()
                
                Button {
                    Task { await onReload() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(isLoadingInvitations)

                
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            
            if !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .padding(.bottom)
                .padding(.leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator.opacity(0.6))
        )
        .animation(.snappy, value: message.isEmpty)
    }
    
    @ViewBuilder
    private func invitationRow(_ inv: Invitations, showActions: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.secondary.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "person.2")
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(inv.project_name)
                    .font(.headline)
                    .lineLimit(1)

                Text("From @\(inv.inviter_name) • Role: \(inv.role_key)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if showActions {
                HStack(spacing: 8) {
                    Button(action: {
                        Task { await declineInvitation(inv) }
                    }, label: {
                        HStack(spacing: 10) {
                            if loadingDeclineIds.contains(inv.id) {
                                ProgressView()
                                    .foregroundStyle(.red)
                                    .controlSize(.small)
                            }
                            Text("Decline")
                        }
                    })
                    .disabled(loadingDeclineIds.contains(inv.id))
                    .shake(shakeTrigger)
                    .animation(.snappy, value: loadingDeclineIds.contains(inv.id))
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: {
                        Task { await acceptInvitation(inv) }
                    }, label: {
                        HStack(spacing: 10) {
                            if loadingAcceptIds.contains(inv.id) {
                                ProgressView().controlSize(.small)
                            }
                            Text("Accept")
                        }
                    })
                    .disabled(loadingAcceptIds.contains(inv.id))
                    .shake(shakeTrigger)
                    .animation(.snappy, value: loadingAcceptIds.contains(inv.id))
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func acceptInvitation(_ invitation: Invitations) async {
        loadingAcceptIds.insert(invitation.id)
        message = ""

        defer { loadingAcceptIds.remove(invitation.id) }

        guard let token = KeychainService.loadToken() else {
            message = "Missing token. Please log in again."
            shakeTrigger += 1
            return
        }

        do {
            let data = try await profileService.acceptInvitation(token: token, id: invitation.id)
            invitations.removeAll { $0.id == invitation.id }
            onAccept(data)
        } catch let error as InvitationsError {
            switch error {
            case .invitationsNotFound:
                message = "Invitation not found."
            case .serverError:
                message = "Server error. Please try again."
            }
            shakeTrigger += 1
        } catch {
            message = "An unexpected error occurred. Please try again."
            shakeTrigger += 1
        }
    }

    private func declineInvitation(_ invitation: Invitations) async {
        loadingDeclineIds.insert(invitation.id)
        message = ""

        defer { loadingDeclineIds.remove(invitation.id) }

        guard let token = KeychainService.loadToken() else {
            message = "Missing token. Please log in again."
            shakeTrigger += 1
            return
        }

        do {
            try await profileService.declineInvitation(token: token, id: invitation.id)
            invitations.removeAll { $0.id == invitation.id }
        } catch let error as InvitationsError {
            switch error {
            case .invitationsNotFound:
                message = "Invitation not found."
            case .serverError:
                message = "Server error. Please try again."
            }
            shakeTrigger += 1
        } catch {
            message = "An unexpected error occurred. Please try again."
            shakeTrigger += 1
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var invitations: [Invitations] = [
            Invitations(id: UUID(), project_name: "Forge iOS", inviter_id: UUID(), inviter_name: "lakshya", role_key: "editor", created_at: "02.22.2024"),
            Invitations(id: UUID(), project_name: "Backend API", inviter_id: UUID(), inviter_name: "alex", role_key: "viewer", created_at: "02.22.2024")
        ]
        
        @State var isLoadingInvitations = false
        @State var error: String? = nil
        
        var body: some View {
            ManageInvitesView(
                invitations: $invitations,
                error: $error,
                isLoadingInvitations: $isLoadingInvitations,
                onAccept: { _ in },
                onReload: {}
            )
        }
    }
    
    return PreviewContainer()
        .frame(minWidth: 600, minHeight: 400)
}
