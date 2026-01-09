//
//  ProfileView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var showAddSkill = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                Divider()
                skillsSection
            }
            .padding(20)
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showAddSkill) {
            AddSkillView { newSkill in
                profileStore.profile.skills.append(newSkill)
                profileStore.profile.skills.sort { ($0.kind.rawValue, $0.name.lowercased()) < ($1.kind.rawValue, $1.name.lowercased()) }
                profileStore.save()
            }
            .frame(minWidth: 420, minHeight: 280)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Display name", text: Binding(
                get: { profileStore.profile.displayName },
                set: { profileStore.profile.displayName = $0; profileStore.save() }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.title2.weight(.semibold))

            TextField("Headline (e.g., iOS Developer • Backend • ML)", text: Binding(
                get: { profileStore.profile.headline },
                set: { profileStore.profile.headline = $0; profileStore.save() }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skills").font(.title3).fontWeight(.semibold)
                Spacer()
                Button {
                    showAddSkill = true
                } label: {
                    Label("Add Skill", systemImage: "plus")
                }
            }

            if profileStore.profile.skills.isEmpty {
                Text("No skills yet. Add your languages, frameworks, and tools.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(groupedSkills.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kindTitle(kind))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(groupedSkills[kind] ?? []) { skill in
                            SkillRow(skill: skill) { updated in
                                updateSkill(updated)
                            } onDelete: {
                                deleteSkill(skill.id)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var groupedSkills: [SkillKind: [Skill]] {
        Dictionary(grouping: profileStore.profile.skills, by: { $0.kind })
    }

    private func kindTitle(_ kind: SkillKind) -> String {
        switch kind {
        case .language: return "Languages"
        case .framework: return "Frameworks"
        case .tool: return "Tools"
        }
    }

    private func updateSkill(_ updated: Skill) {
        if let idx = profileStore.profile.skills.firstIndex(where: { $0.id == updated.id }) {
            profileStore.profile.skills[idx] = updated
            profileStore.save()
        }
    }

    private func deleteSkill(_ id: UUID) {
        profileStore.profile.skills.removeAll { $0.id == id }
        profileStore.save()
    }
}



#Preview {
    ProfileView()
        .environmentObject(ProfileStore(username: "preview-user"))
}

