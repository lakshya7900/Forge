//
//  AIManager.swift
//  Forge
//
//  Created by Lakshya Agarwal on 4/30/26.
//

import Foundation

struct AIManager {
//    static let apiKey = "AIzaSyDizs5bVijF483Ppuw95TkIKZR_YHCmSAc"
    static let apiKey = ""
    static let model = "gemini-3-flash-preview"
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

    struct Message: Codable {
        let role: String   // "user" or "model"
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    struct Request: Codable {
        let systemInstruction: SystemInstruction
        let contents: [Message]
        let generationConfig: GenerationConfig
    }

    struct SystemInstruction: Codable {
        let parts: [Part]
    }

    struct GenerationConfig: Codable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    struct Response: Codable {
        let candidates: [Candidate]
        struct Candidate: Codable {
            let content: Message
        }
    }

    static func send(history: [Message], systemPrompt: String) async throws -> String {
        let body = Request(
            systemInstruction: SystemInstruction(parts: [Part(text: systemPrompt)]),
            contents: history,
            generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 1024)
        )

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.candidates.first?.content.parts.first?.text ?? ""
    }
}
