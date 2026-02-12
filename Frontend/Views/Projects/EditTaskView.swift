//
//  EditTaskView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss

    let members: [ProjectMember]
    let task: TaskItem
    let projectID: UUID
    let allTasks: [TaskItem]
    let onSave: (TaskItem) -> Void
    let onDelete: () -> Void
    
    @State private var taskService = TaskService()

    @State private var title: String
    @State private var details: String
    @State private var status: TaskStatus
    @State private var assigneeId: UUID? = nil
    @State private var difficulty: Double
    @State private var showDeleteConfirm = false
    
    // UI state
    @State private var message: String = ""
    @State private var isLoading = false
    @State private var shakeTrigger: Int = 0

    init(task: TaskItem, members: [ProjectMember], projectID: UUID, allTasks: [TaskItem], onSave: @escaping (TaskItem) -> Void, onDelete: @escaping () -> Void) {
        self.task = task
        self.members = members
        self.projectID = projectID
        self.allTasks = allTasks
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: task.title)
        _details = State(initialValue: task.details)
        _status = State(initialValue: task.status)
        _assigneeId = State(initialValue: task.assigneeId)
        _difficulty = State(initialValue: Double(task.difficulty))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Task")
                .font(.title2).fontWeight(.semibold)

            Form {
                TextField("Title", text: $title)
                    .disabled(true)

                TextField("Details", text: $details, axis: .vertical)
                    .lineLimit(3...8)

                Picker("Status", selection: $status) {
                    ForEach(TaskStatus.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }

                Picker("Assignee", selection: $assigneeId) {
                    Text("Unassigned").tag(UUID?.none)
                    ForEach(members) { m in
                        Text(m.username).tag(UUID?.some(m.id))
                    }
                }

                VStack(alignment: .leading) {
                    Text("Difficulty: \(Int(difficulty))/5")
                    Slider(value: $difficulty, in: 1...5, step: 1)
                }
            }

            VStack(alignment: .trailing) {
                if !message.isEmpty {
                    HStack {
                        Spacer()
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .transition(.opacity)
                    .padding(.vertical, 6)
                }
                
                HStack {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                    .alert("Delet Task?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            Task { await deleteTask() }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This action can’t be undone.")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.red)
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button(action: {
                        Task{ await updateTask() }
                    }, label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            }
                            
                            Text("Save")
                        }
                    })
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLoading)
                    .shake(shakeTrigger)
                    .animation(.snappy, value: isLoading)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
        .animation(.snappy, value: message)    }
    
    private func nextSortIndex(for status: TaskStatus) -> Int {
        let maxIndex = allTasks
            .filter { $0.status == status }
            .map(\.sortIndex)
            .max() ?? -1
        return maxIndex + 1
    }
    
    private func updateTask() async {
        guard let token = KeychainService.loadToken() else {
            message = "Missing token. Please log in again."
            shakeTrigger += 1
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let sortIndexToSend: Int
            if status != task.status {
                // moving across columns via full edit: append to end of destination column
                sortIndexToSend = nextSortIndex(for: status)
            } else {
                // full edit without move: keep current position
                sortIndexToSend = task.sortIndex
            }
            
            let resp = try await taskService.updateTask(
                token: token,
                projectId: projectID,
                taskId: task.id,
                details: newDetails,
                status: status,
                assigneeID: assigneeId,
                difficulty: Int(difficulty),
                sortIndex: sortIndexToSend
            )
            
            onSave(resp)
            dismiss()
        } catch let error as TaskError {
            switch error {
            case .taskNotFound:
                message = "Task not found"
                
            case .serverError:
                message = "Server error. Please try again."
            }
            shakeTrigger += 1
        } catch {
            message = "Something went wrong. Please try again."
            shakeTrigger += 1
        }
    }
    
    private func deleteTask() async {
        guard let token = KeychainService.loadToken() else {
            message = "Missing token. Please log in again."
            shakeTrigger += 1
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await taskService.deleteTask(
                token: token,
                projectId: projectID,
                taskId: task.id
            )

            onDelete()
            dismiss()
        } catch let error as TaskError {
            switch error {
            case .taskNotFound:
                message = "Task not found"
            case .serverError:
                message = "Server error. Please try again."
            }
            shakeTrigger += 1
        } catch {
            message = "Failed to delete task. Please try again."
            shakeTrigger += 1
        }
    }
}

#Preview {
        let members: [ProjectMember] = [
            ProjectMember(id: UUID(), username: "lakshya7900", roleKey: "frontend"),
            ProjectMember(id: UUID(), username: "alex", roleKey: "backend")
        ]

        let projectID = UUID()

        let tasks: [TaskItem] = [
            TaskItem(
                id: UUID(),
                title: "Fix navigation bug",
                details: "Tapping back pops two levels in certain flows.",
                status: .backlog,
                assigneeId: nil,
                assigneeUsername: nil,
                difficulty: 3,
                createdAt: Date(),
                sortIndex: 0
            ),
            TaskItem(
                id: UUID(),
                title: "Refactor TaskService",
                details: "Move DTO mapping into a single place.",
                status: .backlog,
                assigneeId: members[0].id,
                assigneeUsername: members[0].username,
                difficulty: 2,
                createdAt: Date(),
                sortIndex: 1
            ),
            TaskItem(
                id: UUID(),
                title: "Implement UpdateTask ordering",
                details: "Ensure sortIndex is stable across edits.",
                status: .inProgress,
                assigneeId: members[1].id,
                assigneeUsername: members[1].username,
                difficulty: 4,
                createdAt: Date(),
                sortIndex: 0
            )
        ]
    
    EditTaskView(
        task: tasks[0],
        members: members,
        projectID: projectID,
        allTasks: tasks,
        onSave: { _ in },
        onDelete: { }
    )
}
