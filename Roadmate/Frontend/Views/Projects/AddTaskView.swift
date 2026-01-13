//
//  AddTaskView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let members: [ProjectMember]
    let onAdd: (TaskItem) -> Void

    @State private var title = ""
    @State private var details = ""
    @State private var status: TaskStatus = .backlog
    @State private var owner: String? = nil
    @State private var difficulty: Double = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Task")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Title", text: $title)
                TextField("Details", text: $details, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Status", selection: $status) {
                    ForEach(TaskStatus.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }

                Picker("Owner", selection: Binding(
                    get: { owner ?? "" },
                    set: { owner = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Unassigned").tag("")
                    ForEach(members, id: \.id) { m in
                        Text(m.username).tag(m.username)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Difficulty: \(Int(difficulty))/5")
                    Slider(value: $difficulty, in: 1...5, step: 1)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let task = TaskItem(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        details: details,
                        status: status,
                        ownerUsername: owner,
                        difficulty: Int(difficulty)
                    )
                    onAdd(task)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
