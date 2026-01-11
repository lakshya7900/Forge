//
//  ProfileView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionState
    @EnvironmentObject private var projectStore: ProjectStore
    @EnvironmentObject private var profileStore: ProfileStore
    
    @State private var showAddSkill = false
    @State private var editingSkill: Skill? = nil
    @State private var showManageSkills = false

    // If you don’t have ProfileStore yet, replace these with @State placeholders.
    private var profile: UserProfile {
        profileStore.profile
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroHeader

                HStack(alignment: .top, spacing: 16) {
                    // Left column
                    VStack(spacing: 16) {
                        skillsCard
                        educationCard
                    }
                    .frame(maxWidth: .infinity)

                    // Right column
                    VStack(spacing: 16) {
                        projectsCard
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 18)
            }
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        
        .sheet(isPresented: $showAddSkill) {
            AddSkillView { newSkill in
                let trimmed = newSkill.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                let exists = profileStore.profile.skills.contains { $0.name.lowercased() == trimmed.lowercased() }
                guard !exists else { return }

                profileStore.profile.skills.append(Skill(name: trimmed, proficiency: newSkill.proficiency))
                profileStore.profile.skills.sort { $0.proficiency > $1.proficiency }
                profileStore.save()
            }
            .frame(minWidth: 520, minHeight: 300)
        }

        .sheet(isPresented: $showManageSkills) {
            ManageSkillsView(
                skills: $profileStore.profile.skills,
                onSave: { profileStore.save() }
            )
        }

    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    avatar

                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(profile.headline.isEmpty ? "Developer" : profile.headline)
                            .foregroundStyle(.secondary)

                        if !profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(profile.bio)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }

                    Spacer()

                    // Quick action(s)
                    Menu {
                        Button("Edit Profile") {
                            // hook later
                        }
                        Divider()
                        Button("Logout", role: .destructive) {
                            session.logout()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.6)

                HStack(spacing: 14) {
                    stat("Projects", "\(projectStore.projects.count)", systemImage: "folder")
                    stat("Skills", "\(profile.skills.count)", systemImage: "bolt.fill")
                    stat("Education", "\(profile.education.count)", systemImage: "graduationcap.fill")
                    Spacer()
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.35),
                            Color.accentColor.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
                .frame(width: 64, height: 64)

            Text(initials(profile.name.isEmpty ? profile.username : profile.name))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    private func stat(_ title: String, _ value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(statColor(title))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Cards

    private var skillsCard: some View {
        card(
            title: "Skills",
            systemImage: "bolt.fill",
            onAdd: { showAddSkill = true },
            onEdit: { showManageSkills = true }
        ) {
            if profile.skills.isEmpty {
                emptyRow("No skills yet.")
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(profile.skills) { s in
                        skillChip(s)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func skillChip(_ s: Skill) -> some View {
        HStack(spacing: 6) {
            Text(s.name)
                .font(.caption)
                .fontWeight(.semibold)

            Text("\(s.proficiency)/10")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            proficiencyTint(s.proficiency)
                .opacity(0.18),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    proficiencyTint(s.proficiency).opacity(0.35),
                    lineWidth: 1
                )
        )
        .foregroundStyle(.primary)
    }

    private var educationCard: some View {
        card(title: "Education", systemImage: "graduationcap.fill") {
            if profile.education.isEmpty {
                emptyRow("No education added.")
            } else {
                VStack(spacing: 10) {
                    ForEach(profile.education) { e in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(e.school)
                                    .font(.headline)
                                Spacer()
                                Text(e.years)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(e.degree)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var projectsCard: some View {
        card(title: "Projects", systemImage: "folder.fill") {
            if projectStore.projects.isEmpty {
                emptyRow("No projects yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(projectStore.projects.prefix(6)) { p in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.secondary.opacity(0.18))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.secondary)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text("\(p.tasks.count) tasks • \(p.members.count) members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if p.isPinned {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.regularMaterial)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Card helper

    private func card<Content: View>(title: String, systemImage: String, onAdd: (() -> Void)? = nil, onEdit: (() -> Void)? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(title)
                        .font(.headline)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(cardAccent(title))
                }
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add \(title)")
                }
                
                if let onEdit {
                    Button (action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit \(title)")
                }
            }

            content()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    private func initials(_ s: String) -> String {
        let parts = s.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(s.prefix(2)).uppercased()
    }
    
    // MARK: - UI Colors
    
    private func proficiencyTint(_ p: Int) -> Color {
        switch p {
        case 1...3: return .blue
        case 4...6: return .orange
        case 7...8: return .green
        default: return .purple
        }
    }
    
    private func statColor(_ title: String) -> Color {
        switch title {
        case "Projects": return .blue
        case "Skills": return .orange
        case "Education": return .purple
        default: return .secondary
        }
    }
    
    private func cardAccent(_ title: String) -> Color {
        switch title {
        case "Skills": return .orange
        case "Education": return .purple
        case "Projects": return .blue
        default: return .secondary
        }
    }

}


#Preview("Profile – Demo") {
    let store = ProjectStore.preview(projects: [
        Project(
            name: "Roadmate",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(title: "Demo", status: .done)],
            ownerMemberId: UUID()
        )
    ])

    let profileStore = ProfileStore.preview(
        profile: UserProfile(
            username: "lakshya",
            name: "Lakshya Agarwal",
            headline: "Full-stack Developer • macOS + SwiftUI",
            bio: "Building Roadmate — a local AI project planner for dev teams. Love clean UI, strong systems, and fast iteration.",
            skills: [
                Skill(name: "Swift", proficiency: 2),
                Skill(name: "SwiftUI", proficiency: 5),
                Skill(name: "Go", proficiency: 7),
                Skill(name: "React", proficiency: 10),
                Skill(name: "PostgreSQL", proficiency: 1),
            ],
            education: [
                Education(school: "Virginia Tech", degree: "B.S. Computer Science", years: "2024–2028")
            ]
        )
    )

    ProfileView()
        .environmentObject(SessionState.preview(username: "lakshya"))
        .environmentObject(store)
        .environmentObject(profileStore)
        .frame(width: 980, height: 700)
}

