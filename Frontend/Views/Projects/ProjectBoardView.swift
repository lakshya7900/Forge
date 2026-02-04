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

    @State private var showAddTask = false
    @State private var editingTask: TaskItem?

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
            List {
                ForEach(tasks) { task in
                    TaskCardView(
                        task: task,
                        members: project.members,
                        onUpdate: { applyTaskUpdate($0) },
                        onEdit: { editingTask = task },
                        onDelete: { deleteTask(task.id) }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .onDrag {
                        NSItemProvider(object: task.id.uuidString as NSString)
                    }
                }
                .onMove { from, to in
                    reorderWithinStatus(status, fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
//            .frame(width: 300, height: 520)
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

    // Reorder tasks within a status column (Trello move)
    private func reorderWithinStatus(_ status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) {
        var col = tasksFor(status)
        col.move(fromOffsets: fromOffsets, toOffset: toOffset)

        // write back updated indices
        for (i, task) in col.enumerated() {
            if let idx = project.tasks.firstIndex(where: { $0.id == task.id }) {
                project.tasks[idx].sortIndex = i
            }
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
    }
}

