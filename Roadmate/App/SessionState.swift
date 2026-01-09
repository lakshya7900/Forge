//
//  SessionState.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import Foundation
import SwiftUI
import Combine

@MainActor
final class SessionState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var username: String?

    func login(username: String) {
        self.username = username
        self.isAuthenticated = true
    }

    func logout() {
        self.username = nil
        self.isAuthenticated = false
    }
}
