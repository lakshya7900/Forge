//
//  ProjectOverviewView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    
    @State private var showAIChat = false
    @State private var showAICard: Bool
    @State private var aiCardCollapsed = false
    @State private var showDeleteWarning = false
    
    @StateObject private var chatManager = ChatManager()
    
    init(project: Binding<Project>) {
        self._project = project
        
        let key = "ai_card_\(project.wrappedValue.id.uuidString)"
        let saved = UserDefaults.standard.object(forKey: key) as? Bool ?? true
        _showAICard = State(initialValue: saved)
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                if showAICard {
                    card {
                        VStack(alignment: .leading, spacing: 10) {

                            HStack {
                                Label("AI Project Assistant", systemImage: "sparkles")
                                    .font(.headline)

                                Spacer()

                                HStack(spacing: 20) {
                                    Button {
                                        withAnimation {
                                            aiCardCollapsed.toggle()
                                        }
                                    } label: {
                                        Image(systemName: aiCardCollapsed ? "chevron.down" : "chevron.up")
                                    }
                                    .buttonStyle(.plain)

                                    Button(role: .destructive) {
                                        showDeleteWarning = true
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    .foregroundStyle(Color.red)
                                    .buttonStyle(.plain)
                                }
                            }

                            if !aiCardCollapsed {
                                Text("Open AI assistant to refine tasks, clarify scope, and improve your project plan.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    showAIChat = true
                                } label: {
                                    Text("Open AI Chat")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                // 1) Progress
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Progress", systemImage: "chart.bar")

                        let done = doneCount
                        let total = project.tasks.count
                        let pct = progressFraction

                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(pct * 100))%")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(progressColor)
                            Text("\(done)/\(total) tasks done")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        ProgressView(value: pct)
                            .progressViewStyle(.linear)
                            .tint(progressColor)
                    }
                }
                
                // 2) Next up (top tasks not done)
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Next Up", systemImage: "list.bullet.rectangle")
                        
                        if nextUp.isEmpty {
                            Text("Nothing queued 🎉")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(nextUp.prefix(5)) { t in
                                HStack(spacing: 10) {
                                    Image(systemName: t.status.systemImage)
                                        .foregroundStyle(statusColor(t.status))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            if let assignee = t.assigneeUsername, !assignee.isEmpty {
                                                Text(assignee).foregroundStyle(.secondary)
                                            } else {
                                                Text("Unassigned").foregroundStyle(.secondary)
                                            }
                                            Text("• D\(t.difficulty)")
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.subheadline)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(t.status.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                // 3) Status breakdown
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Task Breakdown", systemImage: "square.grid.2x2")

                        HStack(spacing: 10) {
                            FlowLayout(spacing: 8) {
                                ForEach(project.members) { m in
                                    chip("\(m.username) • \(m.displayRole)", roleKey: m.roleKey)
                                }
                            }
                        }
                    }
                }

                // 4) Team summary
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Team", systemImage: "person.2")

                        if project.members.isEmpty {
                            Text("No members yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 10) {
                                Text("\(project.members.count) members")
                                    .font(.headline)

                                Spacer()

                                Text("Owner: \(ownerName)")
                                    .foregroundStyle(.secondary)
                            }

                            FlowLayout(spacing: 8) {
                                ForEach(project.members) { m in
                                    chip("\(m.username) • \(m.displayRole)", roleKey: m.roleKey)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(16)
        }
        .onExitCommand {
            showAIChat = false
        }
        .sheet(isPresented: $showAIChat) {
            TestView(chatManager: chatManager)
                .onExitCommand {
                    showAIChat = false
                }
//                .toolbar {
//                    ToolbarItem(placement: .destructiveAction) {
//                        Button {
//                            showAIChat = false
//                        } label: {
//                            Image(systemName: "xmark")
//                        }
//                    }
//                }
            
        }
        .alert("Delete AI Assistant?", isPresented: $showDeleteWarning) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    showAICard = false
                    let key = "ai_card_\(project.id.uuidString)"
                    UserDefaults.standard.set(false, forKey: key)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the AI assistant from this project. You won’t be able to access this chat again.")
        }
        .onAppear {
            let key = "ai_card_\(project.id.uuidString)"
            if UserDefaults.standard.object(forKey: key) != nil {
                showAICard = UserDefaults.standard.bool(forKey: key)
            }
        }
    }

    // MARK: - Derived stats

    private var doneCount: Int {
        let tasks = project.tasks
        return tasks.filter { $0.status == .done }.count
    }

    private var progressFraction: Double {
        let total = project.tasks.count
        guard total > 0 else { return 0 }
        return Double(doneCount) / Double(total)
    }

    private var ownerName: String {
        project.members.first(where: { $0.id == project.ownerMemberId })?.username ?? "—"
    }

    private func count(for status: TaskStatus) -> Int {
        project.tasks.filter { $0.status == status }.count
    }

    private var nextUp: [TaskItem] {
        // Prioritize In Progress, then Backlog, then Blocked
        let order: [TaskStatus] = [.inProgress, .backlog, .blocked]
        return project.tasks
            .filter { $0.status != .done }
            .sorted { a, b in
                let ia = order.firstIndex(of: a.status) ?? 999
                let ib = order.firstIndex(of: b.status) ?? 999
                if ia != ib { return ia < ib }
                return a.createdAt > b.createdAt
            }
    }

    // MARK: - UI helpers

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private func statusPill(_ status: TaskStatus) -> some View {
        let c = count(for: status)
        let color = statusColor(status)

        return HStack(spacing: 8) {
            Image(systemName: status.systemImage)
                .foregroundStyle(color)

            Text(status.title)

            Spacer()

            Text("\(c)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .font(.subheadline)
        .padding(10)
        .frame(minWidth: 160)
        .background(
            color.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .backlog: return .blue
        case .inProgress: return .orange
        case .blocked: return .red
        case .done: return .green
        }
    }

    private func chip(_ text: String, roleKey: String) -> some View {
        let color = roleColor(roleKey)

        return Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }
    
    private func roleColor(_ roleKey: String) -> Color {
        if let role = ProjectRole(rawValue: roleKey) {
            switch role {
            case .frontend: return .blue
            case .backend: return .green
            case .fullstack: return .teal
            case .pm: return .orange
            case .qa: return .pink
            }
        }
        return .gray
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var progressColor: Color {
        switch progressFraction {
        case 0.75...1: return .green
        case 0.4..<0.75: return .blue
        case 0.15..<0.4: return .orange
        default: return .red
        }
    }
}
