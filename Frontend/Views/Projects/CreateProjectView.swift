//
//  CreateProjectView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//

import SwiftUI

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionState

    let onCreate: (Project) -> Void

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Project name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let owner = ProjectMember(
                        username: session.username ?? "me",
                        roleKey: ProjectRole.fullstack.rawValue
                    )

                    let project = Project(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description,
                        members: [owner],
                        tasks: [],
                        ownerMemberId: owner.id,                    )

                    onCreate(project)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

//#Preview {
//    CreateProjectView(onCreate: { _ in })
//        .environmentObject(SessionState())
//}
