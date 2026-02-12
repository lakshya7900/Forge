//
//  ProjectBoardView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI
import UniformTypeIdentifiers

struct ProjectBoardView: View {
    @Binding var project: Project

    @State private var taskService = TaskService()
    
    @State private var showAddTask = false
    @State private var editingTask: TaskItem?
    
    @State private var isSyncingTasks = false
    @State private var draggingTaskID: UUID? = nil

    var body: some View {
        VStack(spacing: 12) {
            headerBar

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(TaskStatus.allCases) { status in
                        boardColumn(status)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(projectId: project.id, members: project.members) { task in
                var t = task
                t.sortIndex = nextSortIndex(for: t.status)
                project.tasks.append(t)
                normalizeSortIndexes(for: t.status)
            }
            .frame(minWidth: 520, minHeight: 360)
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(
                task: task,
                members: project.members,
                projectID: project.id,
                allTasks: project.tasks,
                onSave: { updated in
                    applyTaskUpdate(updated)
                },
                onDelete: {
                    deleteTask(task.id)
                }
            )
        }
        .padding(12)
    }

    private var headerBar: some View {
        HStack {
            Label("Board", systemImage: "square.grid.3x1.folder.badge.plus")
                .font(.headline)

            Spacer()

            Button {
                showAddTask = true
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            
            
            if isSyncingTasks {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 8)
            }
        }
    }


    // MARK: - Column

    private func boardColumn(_ status: TaskStatus) -> some View {
        let tasks = tasksFor(status)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.color)
                Text(status.title)
                    .font(.headline)

                Spacer()

                Text("\(tasks.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            // Trello-like column list (reorder + drop)
            // Trello-like column list (drag to reorder + drop across columns)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            members: project.members,
                            onUpdate: { applyTaskUpdate($0) },
                            onEdit: { editingTask = task },
                            onDelete: { deleteTask(task.id) }
                        )
                        .padding(.vertical, 6)
                        .onDrag {
                            draggingTaskID = task.id
                            return NSItemProvider(object: task.id.uuidString as NSString)
                        }
                        // Reorder within the same status by dropping onto another card
                        .onDrop(of: [UTType.text], delegate: TaskReorderDropDelegate(
                            targetTask: task,
                            targetStatus: status,
                            project: $project,
                            draggingTaskID: $draggingTaskID,
                            tasksFor: tasksFor,
                            normalizeSortIndexes: normalizeSortIndexes,
                            syncColumn: { s in Task { await syncColumn(s) } }
                        ))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollContentBackground(.hidden)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(status.color.opacity(0.15), lineWidth: 1)
            )
            .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                handleDrop(providers, to: status)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 300)
    }

    // MARK: - Data helpers

    private func tasksFor(_ status: TaskStatus) -> [TaskItem] {
        project.tasks
            .filter { $0.status == status }
            .sorted { (a: TaskItem, b: TaskItem) -> Bool in
                if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
                return a.createdAt < b.createdAt
            }
    }

    private func nextSortIndex(for status: TaskStatus) -> Int {
        (tasksFor(status).map { $0.sortIndex }.max() ?? -1) + 1
    }

    private func applyTaskUpdate(_ updated: TaskItem) {
        if let idx = project.tasks.firstIndex(where: { $0.id == updated.id }) {
            project.tasks[idx] = updated
        }
        normalizeSortIndexes(for: updated.status)
    }

    private func deleteTask(_ id: UUID) {
        if let t = project.tasks.first(where: { $0.id == id }) {
            let status = t.status
            project.tasks.removeAll { $0.id == id }
            normalizeSortIndexes(for: status)
        } else {
            project.tasks.removeAll { $0.id == id }
        }
    }

    private func normalizeSortIndexes(for status: TaskStatus) {
        let col = tasksFor(status)
        for (i, task) in col.enumerated() {
            if let idx = project.tasks.firstIndex(where: { $0.id == task.id }) {
                project.tasks[idx].sortIndex = i
            }
        }
    }

    // MARK: - Drag & drop across columns

    private func handleDrop(_ providers: [NSItemProvider], to status: TaskStatus) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let str = String(data: data, encoding: .utf8),
                      let id = UUID(uuidString: str)
                else { return }

                DispatchQueue.main.async {
                    moveTask(id: id, to: status)
                }
            }
        }
        return true
    }

    private func moveTask(id: UUID, to newStatus: TaskStatus) {
        guard let idx = project.tasks.firstIndex(where: { $0.id == id }) else { return }
        let oldStatus = project.tasks[idx].status
        if oldStatus == newStatus { return }

        project.tasks[idx].status = newStatus
        project.tasks[idx].sortIndex = nextSortIndex(for: newStatus)

        // re-normalize both columns
        normalizeSortIndexes(for: oldStatus)
        normalizeSortIndexes(for: newStatus)
        
        
        // Persist: moved task + updated ordering in both columns
        Task {
            isSyncingTasks = true
            async let firstSync = syncColumn(oldStatus)
            async let secondSync = syncColumn(newStatus)
            await firstSync
            await secondSync
            isSyncingTasks = false
        }
    }
    
    
    // MARK: - Backend sync helpers

    /// Persists status + sortIndex for every task in the given status column.
    /// This keeps DB sort_index consistent with the UI after drag/drop.
    private func syncColumn(_ status: TaskStatus) async {
        guard let token = KeychainService.loadToken() else { return }

        // Snapshot the column order as it currently exists in UI
        let col = tasksFor(status)
        if col.isEmpty { return }

        // Removed isSyncingTasks management from here
        for task in col {
            // Find the most up-to-date version from the project array
            guard let current = project.tasks.first(where: { $0.id == task.id }) else { continue }
            do {
                // IMPORTANT: this assumes you have a backend route like:
                // PUT /me/projects/:projectId/tasks/:taskId
                // that accepts { status, sort_index } (and can ignore missing fields).
                _ = try await taskService.updateTask(
                    token: token,
                    projectId: project.id,
                    taskId: current.id,
                    status: current.status,
                    sortIndex: current.sortIndex
                )
            } catch {
                // Keep UI responsive; you can surface a toast later.
                // print("Sync task order failed:", error)
            }
        }
    }
}

private struct TaskReorderDropDelegate: DropDelegate {
    let targetTask: TaskItem
    let targetStatus: TaskStatus

    @Binding var project: Project
    @Binding var draggingTaskID: UUID?

    let tasksFor: (TaskStatus) -> [TaskItem]
    let normalizeSortIndexes: (TaskStatus) -> Void
    let syncColumn: (TaskStatus) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTaskID else { return }
        guard draggingID != targetTask.id else { return }

        // Only reorder within the same column/status.
        guard let draggingIdx = project.tasks.firstIndex(where: { $0.id == draggingID }) else { return }
        let draggingStatus = project.tasks[draggingIdx].status
        guard draggingStatus == targetStatus else { return }

        // Build the ordered column, move dragged item to the target position, then write back sort indexes.
        var col = tasksFor(targetStatus)
        guard let from = col.firstIndex(where: { $0.id == draggingID }),
              let to = col.firstIndex(where: { $0.id == targetTask.id }) else { return }

        if from == to { return }

        let moved = col.remove(at: from)
        col.insert(moved, at: to)

        for (i, task) in col.enumerated() {
            if let idx = project.tasks.firstIndex(where: { $0.id == task.id }) {
                project.tasks[idx].sortIndex = i
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggingTaskID != nil else { return false }
        // Persist the new ordering for this status once the drop completes.
        syncColumn(targetStatus)
        draggingTaskID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // no-op
    }
}
