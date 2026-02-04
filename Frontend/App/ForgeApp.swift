//
//  RoadmateApp.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

@main
struct ForgeApp: App {
    @State private var session = SessionState()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated, let username = session.username {
                    AuthenticatedRootView(username: username)
                } else {
                    LoginView()
                }
            }
            .environment(session)
            .environment(appState)
        }
    }
}

private struct AuthenticatedRootView: View {
    @State private var projectStore: ProjectStore

    init(username: String) {
        _projectStore = State(wrappedValue: ProjectStore(username: username))
    }

    var body: some View {
        RootView()
            .environment(projectStore)
    }
}
