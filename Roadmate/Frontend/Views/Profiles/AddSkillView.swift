//
//  AddSkillView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct AddSkillView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Skill) -> Void

    @State private var name : String = ""
    @State private var proficiency: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Skill")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name (e.g., Swift, React, Postgres)", text: $name)

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
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    onAdd(Skill(name: trimmed, proficiency: Int(proficiency)))
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

#Preview {
    AddSkillView { _ in }
        .frame(width: 600, height: 200)
}

