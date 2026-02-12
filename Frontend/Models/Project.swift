//
//  Project.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var members: [ProjectMember]
    var tasks: [TaskItem]
    var createdAt: Date = Date()
    var isPinned: Bool = false
    var sortIndex: Int = 0
    var customRoles: [String] = []
    var ownerMemberId: UUID
}
