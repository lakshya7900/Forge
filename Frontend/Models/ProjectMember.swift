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

struct Invitations: Decodable, Identifiable {
    let id: UUID
    let project_name: String
    let inviter_id: UUID
    let inviter_name: String
    let role_key: String
    let created_at: String
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
