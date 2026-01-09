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

    @State private var kind: SkillKind = .language
    @State private var name: String = ""
    @State private var proficiency: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Skill")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Picker("Type", selection: $kind) {
                    ForEach(SkillKind.allCases) { k in
                        Text(k.rawValue.capitalized).tag(k)
                    }
                }

                TextField("Name (e.g., Swift, React, Postgres)", text: $name)

                VStack(alignment: .leading) {
                    Text("Proficiency: \(Int(proficiency))/10")
                    Slider(value: $proficiency, in: 1...10, step: 1)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let skill = Skill(kind: kind, name: name.trimmingCharacters(in: .whitespacesAndNewlines), proficiency: Int(proficiency))
                    onAdd(skill)
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
}

