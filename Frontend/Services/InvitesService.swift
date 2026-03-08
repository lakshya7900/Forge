//
//  InvitesService.swift
//  Forge
//
//  Created by Lakshya Agarwal on 2/12/26.
//

import Foundation

enum InvitesError: Error {
    case userNotFound
    case inviteAlreadyExists
    case noAccess
    case inviteNotFound
    case serverError
}

struct UserMini: Decodable, Identifiable {
    let id: String
    let username: String
}

struct Invite: Decodable {
    let id: String
    let project_id: String
    let inviter_id: String
    let invitee_id: String
    let role_key: String
    let status: String
    let created_at: String
}

struct InviteWithUsers: Decodable {
    let id: String
    let project_id: String
    let inviter_id: String
    let invitee_id: String
    let invitee_username: String
    let role_key: String
    let status: String
    let created_at: String
}

struct ProjectInvitesResponse: Decodable {
    let pending: [InviteWithUsers]
    let declined: [InviteWithUsers]
    let accepted: [InviteWithUsers]
}

struct CreateInviteRequest: Encodable {
    let username: String
    let role_key: String
}

final class InvitesService {
    func searchUsers(token: String, query: String) async throws -> [UserMini] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.count < 2 { return [] }

        var comps = URLComponents(url: AppConfig.apiBaseURL.appendingPathComponent("/me/users/search"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "q", value: q)]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }

        return try JSONDecoder().decode([UserMini].self, from: data)
    }
    
    func sendInvite(token: String, projectId: UUID, username: String, roleKey: String) async throws -> Invite {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/invites")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateInviteRequest(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            role_key: roleKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw InvitesError.serverError
        }
        
        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(Invite.self, from: data)
            
        case 404:
            throw InvitesError.userNotFound
            
        case 409:
            throw InvitesError.inviteAlreadyExists
            
        case 403:
            throw InvitesError.noAccess
            
        default:
            throw InvitesError.serverError
        }
    }
    
    func getProjectInvites(token: String, projectId: UUID) async throws -> ProjectInvitesResponse {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/invites")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw InvitesError.serverError
        }
        
        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(ProjectInvitesResponse.self, from: data)
            
        case 403:
            throw InvitesError.noAccess
            
        default:
            throw InvitesError.serverError
        }
    }

    func deleteInvite(token: String, inviteId: UUID) async throws {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/invites/\(inviteId.uuidString.lowercased())")

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw InvitesError.serverError
        }

        switch http.statusCode {
        case 200:
            return
        case 404:
            throw InvitesError.inviteNotFound
        case 403:
            throw InvitesError.noAccess
        default:
            throw InvitesError.serverError
        }
    }
}
