//
//  EditSkillView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//


import SwiftUI

struct EditSkillView: View {
    @Environment(\.dismiss) private var dismiss

    let skill: Skill
    let onSave: (Skill) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var proficiency: Double

    init(skill: Skill, onSave: @escaping (Skill) -> Void, onDelete: @escaping () -> Void) {
        self.skill = skill
        self.onSave = onSave
        self.onDelete = onDelete

        _name = State(initialValue: skill.name)
        _proficiency = State(initialValue: Double(skill.proficiency))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Skill")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Skill", text: $name)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Proficiency")
                        Spacer()
                        Slider(value: $proficiency, in: 1...10, step: 1)
                        Text("\(Int(proficiency))/10")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Color(.systemRed))

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    let updated = Skill(id: skill.id, name: trimmed, proficiency: Int(proficiency))
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 260)
    }
}

#Preview {
    EditSkillView(
        skill: Skill(name: "SwiftUI", proficiency: 7),
        onSave: { _ in },
        onDelete: {}
    )
    .frame(width: 600, height: 200)
}
