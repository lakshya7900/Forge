//
//  RootView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionState
    @State private var route: SidebarRoute? = .projects

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $route)
        } detail: {
            switch route {
            case .projects:
                EmptyStateView()
                    .overlay(alignment: .topLeading) {
                        Text("Projects (Step 4)")
                            .padding(20)
                            .foregroundStyle(.secondary)
                    }

            case .profile:
                ProfileView()

            case .planner:
                EmptyStateView()
                    .overlay(alignment: .topLeading) {
                        Text("AI Planner (Later)")
                            .padding(20)
                            .foregroundStyle(.secondary)
                    }

            case .none:
                EmptyStateView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Log Out") { session.logout() }
            }
        }
    }
}


#Preview {
    RootView()
        .environmentObject(SessionState())
}

