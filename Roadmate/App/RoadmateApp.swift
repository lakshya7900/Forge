//
//  RoadmateApp.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

@main
struct RoadmateApp: App {
    @StateObject private var session = SessionState()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated, let username = session.username {
                    RootView()
                        .environmentObject(ProfileStore(username: username))
                } else {
                    LoginView()
                }
            }
            .environmentObject(session)
        }
    }
}


