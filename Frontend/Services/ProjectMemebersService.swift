//
//  ProjectMemebersService.swift
//  Forge
//
//  Created by Lakshya Agarwal on 3/6/26.
//

import Foundation

enum ProjectMembersError: Error {
    case memberNotFound
    case notOwner
    case serverError
}

struct UpdateMemeberRoleRequest: Encodable {
    var role_key: String
}

final class ProjectMembersService {
    func updateMemberRole(token: String, projectId: UUID, memberId: UUID, roleKey: String) async throws {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/members/\(memberId.uuidString.lowercased())")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = UpdateMemeberRoleRequest(
            role_key: roleKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        req.httpBody = try JSONEncoder().encode(body)
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else{
            throw ProjectMembersError.serverError
        }
        
        switch http.statusCode {
        case 200:
            return
        case 404:
            throw ProjectMembersError.memberNotFound
        default:
            throw ProjectMembersError.serverError
        }
    }
    
    func deleteMember(token: String, projectId: UUID, memberId: UUID) async throws {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/members/\(memberId.uuidString.lowercased())")
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else{
            throw ProjectMembersError.serverError
        }
        
        switch http.statusCode {
        case 200:
            return
        case 404:
            throw ProjectMembersError.memberNotFound
        case 403:
            throw ProjectMembersError.notOwner
        default:
            throw ProjectMembersError.serverError
        }
    }
}
