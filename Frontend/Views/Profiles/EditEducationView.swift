//
//  EditEducationView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//


import SwiftUI

struct EditEducationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var school : String
    @State private var degree : String
    @State private var major : String
    
    @State private var startYear: Int
    @State private var endYear: Int
    
    let education: Education
    let onSave: (Education) -> Void
    let onDelete: () -> Void

    init(education: Education, onSave: @escaping (Education) -> Void, onDelete: @escaping () -> Void) {
        self.education = education
        self.onSave = onSave
        self.onDelete = onDelete

        _school = State(initialValue: education.school)
        _degree = State(initialValue: education.degree)
        _major = State(initialValue: education.major)
        _startYear = State(initialValue: Int(education.startyear))
        _endYear = State(initialValue: Int(education.endyear))
    }
    
    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 40)...(current + 15))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Education")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("School Name", text: $school)
                TextField("Degree", text: $degree)
                TextField("Major", text: $major)
                
                HStack() {
                    HStack {
                        Text("Start Year")
                        Picker("Start", selection: $startYear) {
                            ForEach(yearRange, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                    
                    HStack {
                        Text("Graduation Year")
                        Picker("Graduation", selection: $endYear) {
                            ForEach(yearRange, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: startYear) { _, newStart in
                    // keep end >= start
                    if endYear < newStart { endYear = newStart }
                }
                .onChange(of: endYear) { _, newEnd in
                    // keep end >= start
                    if newEnd < startYear { startYear = newEnd }
                }
            }

            HStack {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Save") {
                    let trimmedSchool = school.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedSchool.isEmpty else { return }

                    let edu = Education(
                        id: education.id,
                        school: trimmedSchool,
                        degree: degree.trimmingCharacters(in: .whitespacesAndNewlines),
                        major: major.trimmingCharacters(in: .whitespacesAndNewlines),
                        startyear: startYear,
                        endyear: endYear
                    )
                    
                    onSave(edu)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 260)
    }
}

#Preview {
    EditEducationView(
        education: Education(school: "Virginia Tech", degree: "Bachelor's", major: "Computer Science", startyear: 2024, endyear: 2028),
        onSave: { _ in },
        onDelete: {}
    )
    .frame(width: 520, height: 250)
}

