//
//  UserProfile.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import SwiftUI
import Foundation

struct UserProfile: Codable, Equatable {
    var username: String
    var name: String = ""
    var headline: String = ""
    var bio: String = ""
    var skills: [Skill] = []
    var education: [Education] = []
}

struct Skill: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var proficiency: Int  // 1...10
}

struct Education: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var school: String
    var degree: String
    var major: String
    var startyear: Int
    var endyear: Int
}

extension UserProfile {
    static func defaultProfile(for username: String) -> UserProfile {
        // If your struct uses different field names, adjust here.
        UserProfile(
            username: username,
            name: username,
            headline: "",
            bio: "",
            skills: [],
            education: []
        )
    }
}
