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
    
    let onAccept: (Invitations) -> Void
    let onDecline: (Invitations) -> Void
    
    @State private var profileService = ProfileService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if invitations.isEmpty {
                ContentUnavailableView("No Invitations", systemImage: "bell", description: Text("You’re all caught up."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(invitations, id: \.id) { inv in
                            invitationRow(inv, showActions: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
    }

    private var header: some View {
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

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
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
                    Button("Decline") {
                        onDecline(inv)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button("Accept") {
                        onAccept(inv)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var invitations: [Invitations] = [
            Invitations(id: UUID(), project_name: "Forge iOS", inviter_id: UUID(), inviter_name: "lakshya", role_key: "editor", created_at: "02.22.2024"),
            Invitations(id: UUID(), project_name: "Backend API", inviter_id: UUID(), inviter_name: "alex", role_key: "viewer", created_at: "02.22.2024")
        ]
        
        var body: some View {
            ManageInvitesView(
                invitations: $invitations,
                onAccept: { _ in },
                onDecline: { _ in }
            )
        }
    }
    
    return PreviewContainer()
        .frame(minHeight: 400)
}
