//
//  ManageSkillView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//

import SwiftUI

struct ManageSkillsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var skills: [Skill]
    let onSave: () -> Void

    @State private var editing: Skill? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage Skills")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            List {
                ForEach(skills) { s in
                    HStack() {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                            Text("\(s.proficiency)/10")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            remove(s.id)
                        } label: {
                            Image(systemName: "minus")
                                .padding(5)
                        }
                        .clipShape(Circle())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = s }
                }
                .onDelete { indexSet in
                    skills.remove(atOffsets: indexSet)
                    onSave()
                }
            }
            .listStyle(.inset)
        }
        .padding(16)
        .sheet(item: $editing) { s in
            EditSkillView(
                skill: s,
                onSave: { updated in
                    if let idx = skills.firstIndex(where: { $0.id == s.id }) {
                        skills[idx].name = updated.name
                        skills[idx].proficiency = updated.proficiency
                        skills.sort { $0.proficiency > $1.proficiency }
                        onSave()
                    }
                },
                onDelete: {
                    skills.removeAll { $0.id == s.id }
                    onSave()
                }
            )
        }
        .frame(minWidth: 520, minHeight: 420)
    }
    
    private func remove(_ id: UUID) {
        skills.removeAll { $0.id == id }
        onSave()
    }
}

#Preview("Profile – Demo") {
    struct PreviewContainer: View {
        @State var skills: [Skill] = [
            Skill(name: "Swift", proficiency: 2),
            Skill(name: "SwiftUI", proficiency: 5),
            Skill(name: "Go", proficiency: 7),
            Skill(name: "React", proficiency: 10),
            Skill(name: "PostgreSQL", proficiency: 1),
        ]

        var body: some View {
            ManageSkillsView(
                skills: $skills,
                onSave: {}
            )
        }
    }

    return PreviewContainer()
}

