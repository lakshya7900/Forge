//
//  MemberRow.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/10/26.
//

import SwiftUI

struct MemberRow: View {
    let member: ProjectMember
    let roleOptions: [AddMemberView.RoleOption]
    
    let isOwner: Bool

    let onChangeRole: (String) -> Void
    let onRequestAddRole: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(member.username)
                        .font(.headline)

                    
                    if isOwner {
                        Text("Owner")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }

                Text(member.displayRole)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            
            Menu {
                // predefined + custom
                ForEach(roleOptions) { opt in
                    Button(opt.label) { onChangeRole(opt.key) }
                }
                Divider()
                Button("Add Custom Role…") { onRequestAddRole() }
            } label: {
                HStack(spacing: 6) {
                    Text(member.displayRole)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if let onDelete, !isOwner {
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove member")
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.secondary.opacity(0.18))
                .frame(width: 36, height: 36)

            Text(initials(member.username))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    private func initials(_ username: String) -> String {
        let parts = username.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }
}
