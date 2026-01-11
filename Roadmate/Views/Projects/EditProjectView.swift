//
//  EditProjectView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String

    let onSave: (String, String) -> Void

    init(project: Project, onSave: @escaping (String, String) -> Void) {
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Project")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Project name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...8)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description
                    )
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
    }
}
