//
//  AddMemberView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import SwiftUI

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss

    let roleOptions: [RoleOption]
    let onRequestAddRole: () -> Void
    let onAdd: (String, String) -> Void   // username, roleKey

    @State private var username = ""
    @State private var selectedRoleKey: String = ProjectRole.fullstack.rawValue

    struct RoleOption: Identifiable {
        var id: String { key }
        let key: String
        let label: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Team Member")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Username", text: $username)

                Picker("Role", selection: $selectedRoleKey) {
                    ForEach(roleOptions) { opt in
                        Text(opt.label).tag(opt.key)
                    }
                    Divider()
                    Text("Add Custom Role…").tag("__add_custom__")
                }
                .onChange(of: selectedRoleKey) { _, newValue in
                    if newValue == "__add_custom__" {
                        // revert to a safe default and open add-role UI
                        selectedRoleKey = ProjectRole.fullstack.rawValue
                        onRequestAddRole()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !u.isEmpty else { return }
                    onAdd(u, selectedRoleKey)
                    dismiss()
                }
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 260)
    }
}
