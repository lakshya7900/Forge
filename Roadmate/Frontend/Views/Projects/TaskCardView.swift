//
//  TaskCardView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let members: [ProjectMember]
    let onUpdate: (TaskItem) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var local: TaskItem

    init(task: TaskItem,
         members: [ProjectMember],
         onUpdate: @escaping (TaskItem) -> Void,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.task = task
        self.members = members
        self.onUpdate = onUpdate
        self.onEdit = onEdit
        self.onDelete = onDelete
        _local = State(initialValue: task)
    }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(local.status.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(local.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text("D\(local.difficulty)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(local.status.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(local.status.color)
                }

                if !local.details.isEmpty {
                    Text(local.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack {
                    if let owner = local.ownerUsername, !owner.isEmpty {
                        Text(owner).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Unassigned").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(local.status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onEdit() }
        .contextMenu {
            Button("Edit") { onEdit() }

            Divider()

            Picker("Move to", selection: Binding(
                get: { local.status },
                set: { newValue in local.status = newValue; commit() }
            )) {
                ForEach(TaskStatus.allCases) { s in
                    Text(s.title).tag(s)
                }
            }

            Picker("Owner", selection: Binding(
                get: { local.ownerUsername ?? "" },
                set: { v in local.ownerUsername = v.isEmpty ? nil : v; commit() }
            )) {
                Text("Unassigned").tag("")
                ForEach(members) { m in
                    Text(m.username).tag(m.username)
                }
            }

            Divider()

            Button("Delete", role: .destructive) { onDelete() }
        }
        .onChange(of: task) { _, newTask in local = newTask }
    }

    private func commit() {
        onUpdate(local)
    }
}
