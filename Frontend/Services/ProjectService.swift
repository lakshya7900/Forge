//
//  ProjectService.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/19/26.
//

import Foundation

struct ProjectResponse: Decodable {
    let id: String
    let name: String
    let description: String
    let owner_id: String
    let members: [ProjectMember]
    let tasks: [TaskDTO]
    let is_pinned: Bool
    let sort_index: Int
}

struct EditProjectResponse: Decodable {
    let id: String
    let name: String
    let description: String
}

struct CreateProjectRequest: Encodable {
    let name: String
    let description: String
}

struct EditProjectRequest: Encodable {
    let id: String
    let name: String
    let description: String
}

struct ReorderProjectRequest: Encodable {
    let project_ids: [String]
}

final class ProjectService {
    func getProjects(token: String) async throws -> [Project] {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/me/projects")
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }
        
        let dtos = try JSONDecoder().decode([ProjectResponse].self, from: data)
        
        return try dtos.map { dto in
            guard let projectID = UUID(uuidString: dto.id) else {
                throw APIError.badStatus(500, "Invalid project id")
            }
            guard let ownerID = UUID(uuidString: dto.owner_id) else {
                throw APIError.badStatus(500, "Invalid owner id")
            }
            
            // IMPORTANT: set id to backend id
            return Project(
                id: projectID,
                name: dto.name,
                description: dto.description,
                members: dto.members,
                tasks: dto.tasks.map{ TaskItem(from: $0) },
                isPinned: dto.is_pinned,
                sortIndex: dto.sort_index,
                ownerMemberId: ownerID
            )
        }
    }
    
    func createProject(token: String, name: String, description: String) async throws -> Project {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/me/projects")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateProjectRequest (
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.badStatus(code, body)
        }
        
        let dto = try JSONDecoder().decode(ProjectResponse.self, from: data)
        print(dto)
        
        guard let owner_id = UUID(uuidString: dto.owner_id) else {
            throw APIError.badStatus(500, "Invalid owner id")
        }
        
        guard let project_id = UUID(uuidString: dto.id) else {
            throw APIError.badStatus(500, "Invalid project id")
        }
        
        return Project (
            id: project_id,
            name: dto.name,
            description: dto.description,
            members: dto.members,
            tasks: dto.tasks.map { TaskItem(from: $0) },
            sortIndex: dto.sort_index,
            ownerMemberId: owner_id
        )
    }
    
    func editProject(token: String, id: UUID, name: String, description: String) async throws -> EditProjectResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/me/projects")

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = EditProjectRequest(
            id: id.uuidString.lowercased(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }

        return try JSONDecoder().decode(EditProjectResponse.self, from: data)
    }
    
    func deleteProject(token: String, id: UUID) async throws {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(id.uuidString.lowercased())")
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }
    }
    
    func pinProject(token: String, id: UUID, pin: Bool) async throws {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(id.uuidString.lowercased())/\(String(pin).lowercased())")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }
    }
    
    func reorderProject(token: String, orderedIds: [UUID]) async throws {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/me/projects/reorder")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ReorderProjectRequest(project_ids: orderedIds.map { $0.uuidString.lowercased() })
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

