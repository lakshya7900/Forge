//
//  TaskService.swift
//  Forge
//
//  Created by Lakshya Agarwal on 2/2/26.
//

import Foundation

struct CreateTaskRequest: Codable {
    let title: String
    let details: String
    let status: String
    let assignee_id: String?
    let difficulty: Int
    let sort_index: Int?
}

struct UpdateTaskRequest: Encodable {
    let details: String?
    let status: String?
    let assignee_id: String?
    let difficulty: Int?
    let sort_index: Int?
}

final class TaskService {
    func addTask(
        token: String,
        projectId: UUID,
        title: String,
        details: String,
        status: TaskStatus,
        assigneeID: UUID? = nil,
        difficulty: Int
    ) async throws -> TaskItem {
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/tasks")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateTaskRequest (
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status.rawValue,
            assignee_id: assigneeID?.uuidString.lowercased() ?? "",
            difficulty: difficulty,
            sort_index: nil
        )
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.badStatus(code, body)
        }
        
        let dto = try JSONDecoder().decode(TaskDTO.self, from: data)
        return TaskItem(from: dto)
    }
    
    func updateTask(
            token: String,
            projectId: UUID,
            taskId: UUID,
            details: String? = nil,
            status: TaskStatus? = nil,
            assigneeID: UUID? = nil,
            difficulty: Int? = nil,
            sortIndex: Int? = nil
    ) async throws -> TaskItem {
        
        let url = AppConfig.apiBaseURL
            .appendingPathComponent("/me/projects/\(projectId.uuidString.lowercased())/tasks/\(taskId.uuidString.lowercased())")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = UpdateTaskRequest(
            details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status?.rawValue,
            assignee_id: assigneeID?.uuidString.lowercased() ?? "",
            difficulty: difficulty,
            sort_index: sortIndex
        )
        
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        
        guard code == 200 else {
            throw APIError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }
        
        let dto = try JSONDecoder().decode(TaskDTO.self, from: data)
        return TaskItem(from: dto)
    }
}
