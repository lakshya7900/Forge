//
//  TaskItem.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import Foundation
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog, inProgress, blocked, done
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

struct TaskItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var details: String = ""
    var status: TaskStatus = .backlog
    var ownerUsername: String? = nil
    var difficulty: Int = 2 // 1...5
    var createdAt: Date = Date()
    var sortIndex: Int = 0
}
