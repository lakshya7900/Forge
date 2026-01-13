//
//  AuthService.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import Foundation

struct AuthResponse: Decodable {
    let token: String
    let userId: String
    let username: String
}

struct UsernameAvailabilityResponse: Decodable {
    let available: Bool
}

enum AuthError: Error {
    case invalidCredentials
    case usernameTaken
    case server
}

final class AuthService {
//    private let baseURL = URL(string: "http://localhost:8080")!
    struct Configuration {
        static var baseURL: URL {
            guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
                  let url = URL(string: urlString) else {
                fatalError("API_BASE_URL not set correctly in Info.plist")
            }
            return url
        }
    }
    let baseURL = Configuration.baseURL

    func login(username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/login")
        try await authenticate(url: url, username: username, password: password)
    }

    func signup(username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/signup")
        try await authenticate(url: url, username: username, password: password)
    }
    
    func validateUsername(_ username: String) async throws -> Bool {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/auth/validUsername"),
            resolvingAgainstBaseURL: false
        )!

        comps.queryItems = [
            URLQueryItem(name: "username", value: username)
        ]

        let (data, response) = try await URLSession.shared.data(from: comps.url!)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.server
        }

        guard http.statusCode == 200 else {
            throw AuthError.server
        }

        let result = try JSONDecoder().decode(
            UsernameAvailabilityResponse.self,
            from: data
        )

        return result.available
    }

    private func authenticate(
        url: URL,
        username: String,
        password: String
    ) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        req.httpBody = try JSONEncoder().encode([
            "username": username,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.server
        }

        switch http.statusCode {
        case 200:
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            KeychainService.saveToken(auth.token)

        case 401:
            throw AuthError.invalidCredentials

        case 409:
            throw AuthError.usernameTaken

        default:
            throw AuthError.server
        }
    }
}
