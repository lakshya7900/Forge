//
//  SkillRow.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import SwiftUI

struct SkillRow: View {
    @State var skill: Skill
    let onChange: (Skill) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.headline)
                Text("Level \(skill.proficiency)/10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(value: Binding(
                get: { skill.proficiency },
                set: { newValue in
                    skill.proficiency = min(10, max(1, newValue))
                    onChange(skill)
                }
            ), in: 1...10) {
                EmptyView()
            }
            .labelsHidden()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete skill")
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SkillRow(
        skill: Skill(name: "Swift", proficiency: 8),
        onChange: { _ in },
        onDelete: { }
    )
    .padding()
}
