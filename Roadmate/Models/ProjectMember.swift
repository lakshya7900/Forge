//
//  ProjectMemeber.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import Foundation

struct ProjectMember: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var username: String
    var roleKey: String  // "frontend" or "Designer"

    var displayRole: String {
        if let predefined = ProjectRole(rawValue: roleKey) {
            return predefined.label
        }
        return roleKey
    }
}

enum ProjectRole: String, Codable, CaseIterable, Identifiable {
    case frontend, backend, fullstack, pm, qa
    var id: String { rawValue }

    var label: String {
        switch self {
        case .frontend: return "Frontend"
        case .backend: return "Backend"
        case .fullstack: return "Full-stack"
        case .pm: return "Coordinator/PM"
        case .qa: return "QA"
        }
    }
}
