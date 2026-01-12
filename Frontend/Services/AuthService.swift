//
//  AuthService.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import Foundation

enum AuthError: Error {
    case invalidCredentials
}

final class AuthService {
    /// Fake login — always succeeds after delay
    func login(username: String, password: String) async throws {
//        try await Task.sleep(nanoseconds: 700_000_000)

        throw AuthError.invalidCredentials
        
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
    }

    /// Fake signup — always succeeds
    func signup(username: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 700_000_000)

        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
    }
}
