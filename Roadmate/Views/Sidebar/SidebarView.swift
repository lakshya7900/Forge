//
//  SidebarView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

enum SidebarRoute: Hashable {
    case projects
    case profile
    case planner
}

struct SidebarView: View {
    @Binding var selection: SidebarRoute?

    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarRoute.projects) {
                Label("Projects", systemImage: "square.grid.2x2")
            }

            NavigationLink(value: SidebarRoute.profile) {
                Label("Profile", systemImage: "person.crop.circle")
            }

            NavigationLink(value: SidebarRoute.planner) {
                Label("AI Planner", systemImage: "sparkles")
            }
        }
        .navigationTitle("Roadmate")
        .listStyle(.sidebar)
    }
}

#Preview {
    SidebarView(selection: .constant(.profile))
}
