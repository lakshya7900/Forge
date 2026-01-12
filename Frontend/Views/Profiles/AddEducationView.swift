//
//  AddEducationView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/11/26.
//

import SwiftUI

struct AddEducationView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Education) -> Void

    @State private var school : String = ""
    @State private var degree : String = ""
    @State private var major : String = ""
    
    @State private var startYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var endYear: Int = Calendar.current.component(.year, from: Date())
    
    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 40)...(current + 15))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Education")
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
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    let trimmedSchool = school.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedSchool.isEmpty else { return }

                    let edu = Education(
                        school: trimmedSchool,
                        degree: degree.trimmingCharacters(in: .whitespacesAndNewlines),
                        major: major.trimmingCharacters(in: .whitespacesAndNewlines),
                        startyear: startYear,
                        endyear: endYear
                    )
                    onAdd(edu)
                    dismiss()
                }
                .disabled(school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

#Preview {
    AddEducationView { _ in }
        .frame(width: 550, height: 260)
}
