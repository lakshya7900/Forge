//
//  ProfileView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct ProfileView: View {
    @Environment(SessionState.self) private var session
    @Environment(ProjectStore.self) private var projectStore
    
    @State private var profileService = ProfileService()
    @State private var projectService = ProjectService()

    @State private var profile: UserProfile? = nil
    @State private var isLoadingProfile = false
    @State private var profileError: String? = nil

    @State private var showAddSkill = false
    @State private var showManageSkills = false

    @State private var showAddEducation = false
    @State private var educationEditMode = false
    @State private var editingEducation: Education? = nil

    @State private var showEditProjects = false
    @State private var showAllProjects = false

    @State private var showEditProfile = false
    
    @State private var showManageInvitations = false
    @State private var invitations: [Invitations] = []
    @State private var invitationsError: String? = nil
    
    @State private var showAlert = false

    var body: some View {
        ScrollView {
            mainContent
                .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .onAppear { seedPreviewIfNeeded() }
        .task {
            if !isRunningInPreview {
                await loadProfile()
            }
            
            if profileError == nil {
                await getInvitations()
            }
        }
        .modifier(ProfileSheets(
            profile: $profile,
            profileService: profileService,
            projectService: projectService,
            showAddSkill: $showAddSkill,
            showManageSkills: $showManageSkills,
            showAddEducation: $showAddEducation,
            editingEducation: $editingEducation,
            showEditProjects: $showEditProjects,
            showEditProfile: $showEditProfile,
            showManageInvitations: $showManageInvitations,
            invitations: $invitations,
            projectStore: projectStore,
            session: session
        ))
    }
    
    // MARK: - UI Helpers
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 16) {
            if isLoadingProfile && profile == nil {
                ProgressView().padding(.top, 40)
            } else if let profileError {
                VStack(spacing: 10) {
                    Text(profileError).foregroundStyle(.red)
                    
                    HStack() {
                        Button("Retry") { Task { await loadProfile() } }
                            .buttonStyle(.bordered)
                        Button("Log Out") { session.logout() }
                            .tint(Color(.red))
                    }
                }
                .padding(.top, 40)
            } else if let profile {
                profileLoadedView(profile)
            } else {
                Text("No profile loaded.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            }
        }
    }

    private func profileLoadedView(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            heroHeader(profile)

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    skillsCard(profile)
                    educationCard(profile)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    projectsCard
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 18)
        }
    }
    
    // MARK: - Sheets
    private struct ProfileSheets: ViewModifier {
        @Binding var profile: UserProfile?

        let profileService: ProfileService
        let projectService: ProjectService

        @Binding var showAddSkill: Bool
        @Binding var showManageSkills: Bool

        @Binding var showAddEducation: Bool
        @Binding var editingEducation: Education?

        @Binding var showEditProjects: Bool
        @Binding var showEditProfile: Bool
        
        @Binding var showManageInvitations: Bool
        
        @Binding var invitations: [Invitations]

        let projectStore: ProjectStore
        let session: SessionState

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $showAddSkill) {
                    AddSkillView { newSkill in
                        guard var p = profile else { return }
                        p.skills.append(newSkill)
                        profile = p
                    }
                    .frame(width: 600, height: 200)
                }

                .sheet(isPresented: $showManageSkills) {
                    if profile != nil {
                        ManageSkillsView(
                            skills: Binding(
                                get: { profile?.skills ?? [] },
                                set: { newVal in
                                    guard var p = profile else { return }
                                    p.skills = newVal
                                    profile = p
                                }
                            ),
                            onSave: { }
                        )
                        .frame(width: 600, height: 400)
                    }
                }

                .sheet(isPresented: $showAddEducation) {
                    AddEducationView { newEdu in
                        guard var p = profile else { return }
                        p.educations.append(newEdu)
                        profile = p
                    }
                    .frame(width: 550, height: 300)
                }

                .sheet(item: $editingEducation) { edu in
                    EditEducationView(
                        education: edu,
                        onSave: { updated in
                            guard var p = profile else { return }
                            guard let idx = p.educations.firstIndex(where: { $0.id == edu.id }) else { return }

                            p.educations[idx] = Education(
                                id: edu.id,
                                school: updated.school,
                                degree: updated.degree,
                                major: updated.major,
                                startyear: updated.startyear,
                                endyear: updated.endyear
                            )

                            p.educations.sort { a, b in
                                if a.endyear != b.endyear { return a.endyear > b.endyear }
                                return a.startyear > b.startyear
                            }

                            profile = p
                        },
                        onDelete: {
                            guard var p = profile else { return }
                            p.educations.removeAll { $0.id == edu.id }
                            profile = p
                        }
                    )
                    .frame(minWidth: 520, minHeight: 360)
                }

                .sheet(isPresented: $showEditProjects) {
                    ManageProjectsView(
                        projects: Binding(
                            get: { projectStore.projects },
                            set: { newValue in projectStore.projects = newValue }
                        ),
                        onReorder: { orderedIds in
                            for idx in projectStore.projects.indices {
                                projectStore.projects[idx].sortIndex = idx
                            }

                            Task {
                                guard let token = KeychainService.loadToken() else {
                                    return
                                }
                                
                                do {
                                    try await projectService.reorderProject(token: token, orderedIds: orderedIds)
                                    projectStore.save()
                                } catch {
                                    print("Error")
                                }
                            }
                        }
                    )
                    .frame(minWidth: 520, minHeight: 520)
                }

                .sheet(isPresented: $showEditProfile) {
                    if let profile {
                        EditProfileView(
                            user: profile,
                            onSave: { updated in
                                Task {
                                    guard let token = KeychainService.loadToken() else { return }
                                    do {
                                        try await profileService.updateProfile(
                                            token: token,
                                            name: updated.name,
                                            headline: updated.headline,
                                            bio: updated.bio
                                        )
                                        self.profile = updated
                                        session.username = updated.username
                                    } catch {
                                        // optional: error UI
                                    }
                                }
                            }
                        )
                        .frame(minWidth: 600, minHeight: 250)
                    }
                }
            
                .sheet(isPresented: $showManageInvitations) {
                    ManageInvitesView(
                        invitations: $invitations,
                        onAccept: { accepted in
                            Task {
                                guard let token = KeychainService.loadToken() else {
                                    return
                                }
                                
                                do {
                                    let data = try await profileService.acceptInvitation(token: token, id: accepted.id)
                                    invitations.removeAll { $0.id == accepted.id }
                                    projectStore.upsert(data)
                                } catch {
                                    return
                                }
                            }
                        },
                        onDecline: { declined in
                            Task {
                                guard let token = KeychainService.loadToken() else {
                                    return
                                }
                                
                                do {
                                    _ = try await profileService.declineInvitation(token: token, id: declined.id)
                                    invitations.removeAll { $0.id == declined.id }
                                } catch {
                                    return
                                }
                            }
                        }
                    )
                }
                .frame(minHeight: 400)
        }
    }


    // MARK: - Backend

    private func loadProfile() async {
        guard let token = KeychainService.loadToken() else {
            profileError = "Missing token. Please log in again."
            return
        }

        isLoadingProfile = true
        profileError = nil
        defer { isLoadingProfile = false }

        do {
            let p = try await profileService.getProfile(token: token)
            profile = p
        } catch {
            profileError = "Failed to load profile."
        }
    }

    private func saveProfile(_ updated: UserProfile) async {
        guard let token = KeychainService.loadToken() else { return }

        do {
            try await profileService.updateProfile(
                token: token,
                name: updated.name,
                headline: updated.headline,
                bio: updated.bio
            )
            // update local state too
            profile = updated
            // Also keep session username in sync if needed
            session.username = updated.username
        } catch {
            // optional: show toast/alert
        }
    }
    
    private func getInvitations() async {
        guard let token = KeychainService.loadToken() else {
            profileError = "Missing token. Please log in again."
            return
        }

        isLoadingProfile = true
        invitationsError = nil
        defer { isLoadingProfile = false }

        do {
            let i = try await profileService.getInvitations(token: token)
            invitations = i
        } catch {
            invitationsError = "Failed to load profile."
        }
    }

    // MARK: - Hero

    private func heroHeader(_ profile: UserProfile) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    avatar(profile)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name.isEmpty ? profile.username : profile.name)
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

                    HStack(spacing: 10) {
                        Button {
                             showEditProfile = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                             showManageInvitations = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)

                                let count = invitations.count
                                if count > 0 {
                                    Text(count > 99 ? "99+" : "\(count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().opacity(0.6)

                HStack(spacing: 14) {
                    stat("Projects", "\(projectStore.projects.count)", systemImage: "folder")
                    stat("Skills", "\(profile.skills.count)", systemImage: "bolt.fill")
                    stat("Education", "\(profile.educations.count)", systemImage: "graduationcap.fill")
                    Spacer()
                    Button("Log Out", action: { showAlert = true })
                    .alert("Log out of your account?", isPresented: $showAlert, actions: {
                        Button(role: .destructive) {
                            session.logout()
                        } label: {
                            Text("Log Out")
                        }
                    })
                    .tint(.red)
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private func avatar(_ profile: UserProfile) -> some View {
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
                .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                .frame(width: 64, height: 64)

            Text(initials((profile.name.isEmpty ? profile.username : profile.name)))
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
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Cards

    private func skillsCard(_ profile: UserProfile) -> some View {
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
            Text(s.name).font(.caption).fontWeight(.semibold)
            Text("\(s.proficiency)/10").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(proficiencyTint(s.proficiency).opacity(0.18), in: Capsule())
        .overlay(
            Capsule().strokeBorder(proficiencyTint(s.proficiency).opacity(0.35), lineWidth: 1)
        )
        .foregroundStyle(.primary)
    }

    private func educationCard(_ profile: UserProfile) -> some View {
        card(
            title: "Education",
            systemImage: "graduationcap.fill",
            onAdd: { showAddEducation = true },
            onEdit: { educationEditMode = true },
            editMode: $educationEditMode
        ) {
            if profile.educations.isEmpty {
                emptyRow("No education added.")
            } else {
                VStack(spacing: 10) {
                    ForEach(profile.educations) { e in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(e.school).font(.headline)
                                    Spacer()
                                    Text("\(String(e.startyear)) - \(String(e.endyear))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(e.degree) in \(e.major)")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                            if educationEditMode {
                                Button { editingEducation = e } label: {
                                    Image(systemName: "pencil").font(.subheadline)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)
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
                let all = projectStore.projects.sorted {a, b in
                    if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
                    return a.createdAt > b.createdAt
                }
                let shownCount = min(all.count, showAllProjects ? all.count : projectsCollapsedCount)
                let visible = Array(all.prefix(shownCount))

                let desired = projectsNeededHeight(for: visible.count)
                let clampedHeight = min(desired, projectsMaxHeight)
                let shouldScroll = desired > projectsMaxHeight

                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        if shouldScroll {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(visible) { p in projectRow(p) }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(height: clampedHeight)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(visible) { p in projectRow(p) }
                            }
                            .frame(height: clampedHeight, alignment: .top)
                        }
                    }
                    .animation(.snappy, value: showAllProjects)

                    if all.count > projectsCollapsedCount {
                        Button(showAllProjects ? "Show less" : "Show more") {
                            withAnimation(.snappy) { showAllProjects.toggle() }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
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
                .overlay(Image(systemName: "folder.fill").foregroundStyle(.secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.headline).lineLimit(1)
                Text("\(p.tasks.count) tasks • \(p.members.count) members")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
    }

    private let projectRowHeight: CGFloat = 68
    private let projectsCollapsedCount = 3
    private let projectsMaxHeight: CGFloat = 360

    private func projectsNeededHeight(for count: Int) -> CGFloat {
        let spacing: CGFloat = 10
        let totalSpacing = max(0, CGFloat(count - 1)) * spacing
        return CGFloat(count) * projectRowHeight + totalSpacing
    }

    // MARK: - Card helper

    private func card<Content: View>(
        title: String,
        systemImage: String,
        onAdd: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        editMode: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isEditing = editMode?.wrappedValue ?? false

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(title).font(.headline)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(cardAccent(title))
                }

                Spacer()

                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let editMode {
                    Button {
                        editMode.wrappedValue.toggle()
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                            .foregroundStyle(isEditing ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                } else if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(s.prefix(2)).uppercased()
    }

    private func proficiencyTint(_ p: Int) -> Color {
        switch p {
        case 1...3: return .red
        case 4...6: return .blue
        case 7...8: return .green
        default: return .yellow
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
    
    // MARK: - Preview helpers
    
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    @MainActor
    private func seedPreviewIfNeeded() {
        guard isRunningInPreview else { return }
        guard profile == nil else { return }

        profile = UserProfile(
            username: "lakshya",
            name: "Lakshya Agarwal",
            headline: "Full-stack Developer • macOS + SwiftUI",
            bio: "Building Roadmate — a local AI project planner for dev teams. Love clean UI, strong systems, and fast iteration.",
            skills: [
                Skill(name: "Swift", proficiency: 7),
                Skill(name: "SwiftUI", proficiency: 8),
                Skill(name: "Go", proficiency: 6),
                Skill(name: "React", proficiency: 9),
                Skill(name: "PostgreSQL", proficiency: 5),
            ],
            educations: [
                Education(
                    school: "Virginia Tech",
                    degree: "Bachelor's",
                    major: "Computer Science",
                    startyear: 2024,
                    endyear: 2028
                )
            ]
        )
    }
}

//MARK: - Preview Canvas
#Preview("ProfileView – Demo") {
    let store = ProjectStore.preview(projects: [
        Project(
            id: UUID(),
            name: "Roadmate",
            description: "Local AI dev planner for teams.",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [
                TaskItem(id: UUID(), title: "Ship v1", details: "", status: .done, difficulty: 2, createdAt: Date(), sortIndex: 1),
                TaskItem(id: UUID(), title: "Profile Polish", details: "", status: .inProgress, difficulty: 2, createdAt: Date(), sortIndex: 2),
            ],
            ownerMemberId: UUID()
        ),
        Project(
            id: UUID(),
            name: "Side Project",
            description: "Something cool",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [TaskItem(id: UUID(), title: "MVP", details: "", status: .backlog, difficulty: 4, createdAt: Date(), sortIndex: 3)],
            ownerMemberId: UUID()
        ),
        Project(
            id: UUID(),
            name: "Another Project",
            description: "",
            members: [ProjectMember(username: "lakshya", roleKey: "fullstack")],
            tasks: [],
            ownerMemberId: UUID()
        )
    ])

    let session = SessionState()
    
    var invitations: [Invitations] = [
        Invitations(id: UUID(), project_name: "Forge iOS", inviter_id: UUID(), inviter_name: "lakshya", role_key: "editor", created_at: "02.22.2024"),
        Invitations(id: UUID(), project_name: "Backend API", inviter_id: UUID(), inviter_name: "alex", role_key: "viewer", created_at: "02.22.2024")
    ]

    ProfileView()
        .environment(session)
        .environment(store)
        .frame(width: 980, height: 700)
}

