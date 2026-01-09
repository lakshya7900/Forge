//
//  Skills.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import Foundation

enum SkillKind: String, Codable, CaseIterable, Identifiable {
    case language, framework, tool
    var id: String { rawValue }
}

struct Skill: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var kind: SkillKind
    var name: String
    var proficiency: Int // 1 - 10
}
