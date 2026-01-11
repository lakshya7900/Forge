//
//  ProjectTile.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct ProjectTile: View {
    let project: Project
    
    var onPin: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()

                Menu {
                    Button(project.isPinned ? "Unpin" : "Pin") { onPin?() }
                    Button("Edit") { onEdit?() }
                    Divider()
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Text("Delete")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 2)
                        .contentShape(Circle())
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            
            Text(project.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                

            Text("\(project.tasks.count) tasks • \(project.members.count) members")
                .font(.subheadline)
                .foregroundStyle(.green)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(height: 120)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let demoOwner = ProjectMember(username: "me", roleKey: "frontend")
    
    ProjectTile(project: Project(
        name: "Demo: Roadmate Planner",
        description: "SeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeedSeed",
        members: [demoOwner],
        tasks: [TaskItem(title: "Task", status: .backlog)],
        ownerMemberId: demoOwner.id
    ))
    .padding()
    .frame(width: 260)
}

