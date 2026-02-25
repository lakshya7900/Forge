//
//  ManageProjectsView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//


import SwiftUI

struct ManageProjectsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var projects: [Project]
    let onReorder: (_ orderedProjectIDs: [UUID]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reorder Projects")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    let orderedIDs = projects.map { $0.id }
                    onReorder(orderedIDs)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Drag to reorder. This order controls what shows in your Profile.")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            List {
                ForEach(projects) { p in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                                .font(.headline)
                                .lineLimit(1)

                            Text("\(p.tasks.count) tasks • \(p.members.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: move)
            }
            .listStyle(.inset)
        }
        .padding(16)
    }

    private func move(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    let owner = ProjectMember(username: "preview", roleKey: "fullstack")
    let demo = [
        Project(id: UUID(), name: "A", description: "", members: [owner], tasks: [], ownerMemberId: owner.id),
        Project(id: UUID(), name: "B", description: "", members: [owner], tasks: [], ownerMemberId: owner.id),
        Project(id: UUID(), name: "C", description: "", members: [owner], tasks: [], ownerMemberId: owner.id),
    ]

    ManageProjectsView(projects: .constant(demo), onReorder: { _ in })
        .frame(width: 560, height: 520)
}
