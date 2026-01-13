//
//  ProfileService.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/12/26.
//

import Foundation

func updateProfileIfNeeded(token: String, name: String, headline: String, bio: String) async throws {
    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let h = headline.trimmingCharacters(in: .whitespacesAndNewlines)
    let b = bio.trimmingCharacters(in: .whitespacesAndNewlines)

    let url = URL(string: "http://127.0.0.1:8080/me/profile")!
    var req = URLRequest(url: url)
    req.httpMethod = "PUT"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let body = ["name": n, "headline": h, "bio": b]
    req.httpBody = try JSONEncoder().encode(body)

    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
    if code != 200 {
        print("Update profile failed:", code, String(data: data, encoding: .utf8) ?? "")
        throw URLError(.badServerResponse)
    }
}
