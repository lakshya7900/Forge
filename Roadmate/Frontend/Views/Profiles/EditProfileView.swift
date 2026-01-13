//
//  EditProfile.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//


import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let user: UserProfile
    let onSave: (UserProfile) -> Void

    @State private var name: String
    @State private var headline: String
    @State private var bio: String

    init(user: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.user = user
        self.onSave = onSave

        _name = State(initialValue: user.name)
        _headline = State(initialValue: user.headline)
        _bio = State(initialValue: user.bio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Profile")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                TextField("Headline", text: $headline)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(7)
            }

            HStack {
                Spacer()

                Button(action: { dismiss() }) {
                    Text("Cancel")
                }

                Button(action: {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    let updated = UserProfile(
                        username: user.username,
                        name: trimmed,
                        headline: headline,
                        bio: bio,
                        skills: user.skills,
                        education: user.education
                    )
                    onSave(updated)
                    dismiss()
                }) {
                    Text("Save")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 260)
    }
}

#Preview {
    EditProfileView(
        user: UserProfile(
            username: "lakshya",
            name: "Lakshya Agarwal",
            headline: "Full-stack Developer • macOS + SwiftUI",
            bio: "Building Roadmate — a local AI project planner for dev teams. Love clean UI, strong systems, and fast iteration.",
            skills: [
                Skill(name: "Swift", proficiency: 2),
                Skill(name: "SwiftUI", proficiency: 5),
                Skill(name: "Go", proficiency: 7),
                Skill(name: "React", proficiency: 10),
                Skill(name: "PostgreSQL", proficiency: 1),
            ],
            education: [
                Education(school: "Virginia Tech", degree: "Bachelor's", major: "Computer Science", startyear: 2024, endyear: 2028)
            ]
        ),
        onSave: { _ in }
    )
    .frame(width: 600, height: 250)
}

