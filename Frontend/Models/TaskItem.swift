//
//  TaskItem.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import Foundation
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog, inProgress, done, blocked
    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog: return "Backlog"
        case .inProgress: return "In Progress"
        case .blocked: return "Blocked"
        case .done: return "Done"
        }
    }

    var systemImage: String {
        switch self {
        case .backlog: return "tray"
        case .inProgress: return "hammer"
        case .blocked: return "exclamationmark.triangle"
        case .done: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .backlog: return .blue
        case .inProgress: return .orange
        case .blocked: return .red
        case .done: return .green
        }
    }
}

struct TaskDTO: Decodable {
    let id: String
    let title: String
    let details: String
    let status: String
    let assignee_id: String?
    let assignee_username: String?
    let difficulty: Int
    let sort_index: Int
    let created_at: String
}


struct TaskItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var details: String
    var status: TaskStatus
    var assigneeId: UUID?
    var assigneeUsername: String?
    var difficulty: Int
    var createdAt: Date
    var sortIndex: Int
}

extension TaskItem {
    init(from dto: TaskDTO) {
        self.id = UUID(uuidString: dto.id)!
        self.title = dto.title
        self.details = dto.details
        self.status = TaskStatus(rawValue: dto.status) ?? .backlog
        self.assigneeId = dto.assignee_id.flatMap(UUID.init)
        self.assigneeUsername = dto.assignee_username
        self.difficulty = max(1, min(dto.difficulty, 5))
        self.sortIndex = dto.sort_index

        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.date(from: dto.created_at) ?? Date()
    }
}
