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
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated, let username = session.username {
//                    RootView()
//                        .environmentObject(ProfileStore(username: username))
//                        .environmentObject(ProjectStore(username: username))
//                        .environmentObject(appState)
                    AuthenticatedRootView(username: username)
                } else {
                    LoginView()
                }
            }
            .environmentObject(session)
            .environmentObject(appState)
        }
    }
}

private struct AuthenticatedRootView: View {
    @StateObject private var profileStore: ProfileStore
    @StateObject private var projectStore: ProjectStore

    init(username: String) {
        _profileStore = StateObject(wrappedValue: ProfileStore(username: username))
        _projectStore = StateObject(wrappedValue: ProjectStore(username: username))
    }

    var body: some View {
        RootView()
            .environmentObject(profileStore)
            .environmentObject(projectStore)
    }
}
