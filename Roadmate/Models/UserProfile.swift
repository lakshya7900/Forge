//
//  UserProfile.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var headline: String
    var skills: [Skill]
}
