//
//  JSONFormatter.swift
//  Forge
//
//  Created by Lakshya Agarwal on 5/1/26.
//

import Foundation

struct ProjectJSON: Codable {
    var type: String
    var coreProblem: String
    var targetUser: String
    var platform: String
    var usp: String
    var competitors: [String]
    var aiInvolved: Bool
    var uniqueFeatures: [String]
}

struct JSONFormatter {
    static func format(summary: String) async throws -> ProjectJSON {
        let prompt = """
        You are given a one-sentence product summary. Extract structured data from it.

        Summary:
        "\(summary)"

        Return ONLY valid JSON with this exact structure, no markdown, no explanation:
        {
          "type": "",
          "coreProblem": "",
          "targetUser": "",
          "platform": "",
          "usp": "",
          "competitors": [],
          "aiInvolved": true,
          "uniqueFeatures": []
        }
        """

        let history = [AIManager.Message(role: "user", parts: [.init(text: prompt)])]
        let response = try await AIManager.send(history: history, systemPrompt: "You are a JSON extraction assistant. Return only valid JSON, nothing else.")

        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw JSONFormatterError.invalidResponse
        }

        return try JSONDecoder().decode(ProjectJSON.self, from: data)
    }

    enum JSONFormatterError: Error {
        case invalidResponse
    }
}
