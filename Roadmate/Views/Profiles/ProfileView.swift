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
    
    @State private var showAddEducation = false
    @State private var educationEditMode = false
    @State private var editingEducation: Education? = nil
    
    @State private var showEditProjects = false
    @State private var showAllProjects = false

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
            .frame(width: 600, height: 200)
        }

        .sheet(isPresented: $showManageSkills) {
            ManageSkillsView(
                skills: $profileStore.profile.skills,
                onSave: { profileStore.save() }
            )
        }
        
        .sheet(isPresented: $showAddEducation){
            AddEducationView { newEdu in
                let exists = profileStore.profile.education.contains {
                    $0.school.lowercased() == newEdu.school.lowercased() &&
                    $0.degree.lowercased() == newEdu.degree.lowercased() &&
                    $0.major.lowercased() == newEdu.major.lowercased() &&
                    $0.startyear == newEdu.startyear &&
                    $0.endyear == newEdu.endyear
                }
                guard !exists else { return }
                
                profileStore.profile.education.append(newEdu)
                
                profileStore.profile.education.sort { a, b in
                    if a.endyear != b.endyear { return a.endyear > b.endyear }
                    return a.startyear > b.startyear
                }
                
                profileStore.save()
            }
            .frame(width: 550, height: 260)
        }
        
        .sheet(item: $editingEducation) { edu in
            EditEducationView(
                education: edu,
                onSave: { updated in
                    guard let idx = profileStore.profile.education.firstIndex(where: { $0.id == edu.id }) else { return }

                    // preserve the same id
                    profileStore.profile.education[idx] = Education(
                        id: edu.id,
                        school: updated.school,
                        degree: updated.degree,
                        major: updated.major,
                        startyear: updated.startyear,
                        endyear: updated.endyear
                    )

                    // optional: sort newest first
                    profileStore.profile.education.sort { a, b in
                        if a.endyear != b.endyear { return a.endyear > b.endyear }
                        return a.startyear > b.startyear
                    }

                    profileStore.save()
                },
                onDelete: {
                    profileStore.profile.education.removeAll { $0.id == edu.id }
                    profileStore.save()
                }
            )
            .frame(minWidth: 520, minHeight: 360)
        }
         
        .sheet(isPresented: $showEditProjects) {
            ManageProjectsView(projects: $projectStore.projects) {
                projectStore.save()
            }
            .frame(minWidth: 520, minHeight: 520)
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
        card(
            title: "Education",
            systemImage: "graduationcap.fill",
            onAdd: { showAddEducation = true },
            onEdit: { educationEditMode = true },
            editMode: $educationEditMode
        ) {
            if profile.education.isEmpty {
                emptyRow("No education added.")
            } else {
                VStack(spacing: 10) {
                    ForEach(profile.education) { e in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(e.school)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(String(e.startyear)) - \(String(e.endyear))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text("\(e.degree) in \(e.major)")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            
                            if educationEditMode {
                                Button {
                                    editingEducation = e
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)
                                .help("Edit education")
                                .transition(.opacity)
                            }
                        }
                        .animation(.snappy, value: educationEditMode)
                    }
                }
            }
        }
    }

    private var projectsCard: some View {
        card(
            title: "Projects",
            systemImage: "folder.fill",
            onEdit: { showEditProjects = true }
        ) {
            if projectStore.projects.isEmpty {
                emptyRow("No projects yet.")
            } else {
                let all = projectStore.projects

                // how many should be shown right now
                let shownCount = min(all.count, showAllProjects ? all.count : projectsCollapsedCount)
                let visible = Array(all.prefix(shownCount))

                // desired height grows with content until max; after that we scroll
                let desired = projectsNeededHeight(for: visible.count)
                let clampedHeight = min(desired, projectsMaxHeight)
                let shouldScroll = desired > projectsMaxHeight

                VStack(alignment: .leading, spacing: 10) {

                    // Stage logic:
                    // - collapsed: not scrollable
                    // - expanded: grows
                    // - expanded + too many: scrolls
                    Group {
                        if shouldScroll {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(visible) { p in
                                        projectRow(p)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(height: clampedHeight)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(visible) { p in
                                    projectRow(p)
                                }
                            }
                            .frame(height: clampedHeight, alignment: .top)
                        }
                    }
                    .animation(.snappy, value: showAllProjects)

                    // Buttons
                    if all.count > projectsCollapsedCount {
                        HStack(alignment: .center) {
                            if !showAllProjects {
                                Button {
                                    withAnimation(.snappy) {
                                        // Expand
                                        showAllProjects = true
                                    }
                                } label: {
                                    Text("Show more")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            } else {
                                Button {
                                    withAnimation(.snappy) {
                                        // Collapse
                                        showAllProjects = false
                                    }
                                } label: {
                                    Text("Show less")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    
    private func projectRow(_ p: Project) -> some View {
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
    
    private let projectRowHeight: CGFloat = 68     // approx row height (your tile + padding)
    private let projectsCollapsedCount = 3
    private let projectsExpandStep = 5             // "show more" reveals 5 more each click
    private let projectsMaxHeight: CGFloat = 360   // max height before scrolling kicks in

    private func projectsNeededHeight(for count: Int) -> CGFloat {
        // count * rowHeight + spacing between rows
        // spacing is 10 between rows (your VStack spacing)
        let spacing: CGFloat = 10
        let totalSpacing = max(0, CGFloat(count - 1)) * spacing
        return CGFloat(count) * projectRowHeight + totalSpacing
    }



    // MARK: - Card helper

    private func card<Content: View>(
        /// Basics
        title: String,
        systemImage: String,
        /// Optionals
        onAdd: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        editMode: Binding<Bool>? = nil,
        /// Main content
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isEditing = editMode?.wrappedValue ?? false
        
        return VStack(alignment: .leading, spacing: 12) {
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
                
                if let editMode {
                    Button(action: {
                        editMode.wrappedValue.toggle()
                    }, label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                            .foregroundStyle(isEditing ? .green : .secondary)
                    })
                    .buttonStyle(.plain)
                    .help(isEditing ? "Done" : "Edit \(title)")
                } else if let onEdit {
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
        ),
        Project(
            name: "Roadmate1",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(title: "Demo", status: .done)],
            ownerMemberId: UUID()
        ),
        Project(
            name: "Roadmate2",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(title: "Demo", status: .done)],
            ownerMemberId: UUID()
        ),
        Project(
            name: "Roadmate3",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(title: "Demo", status: .done)],
            ownerMemberId: UUID()
        ),
        Project(
            name: "Roadmate4",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(title: "Demo", status: .done)],
            ownerMemberId: UUID()
        ),
        Project(
            name: "Roadmate5",
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
                Education(school: "Virginia Tech", degree: "Bachelor's", major: "Computer Science", startyear: 2024, endyear: 2028)
            ]
        )
    )

    ProfileView()
        .environmentObject(SessionState.preview(username: "lakshya"))
        .environmentObject(store)
        .environmentObject(profileStore)
        .frame(width: 980, height: 700)
}

