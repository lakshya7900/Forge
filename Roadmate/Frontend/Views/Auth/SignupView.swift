//
//  SignupView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//
import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionState

    private let auth = AuthService()

    // Step control
    enum Step { case account, profile }
    @State private var step: Step = .account

    // Account fields
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    // Optional profile fields
    @State private var name = ""
    @State private var headline = ""
    @State private var bio = ""

    // UI state
    @State private var message: String? = nil
    @State private var isLoading = false
    @State private var shakeTrigger: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            header

            if let message {
                complaintRow(message)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Group {
                switch step {
                case .account:
                    accountStep
                case .profile:
                    profileStep
                }
            }
            .animation(.snappy, value: step)

            footerButtons
        }
        .padding(22)
        .frame(minWidth: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(step == .account ? "Create Account" : "Set up your profile")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(step == .account ? "Choose a username and password." : "Optional — you can skip this for now.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    // MARK: - Step 1

    private var accountStep: some View {
        VStack(spacing: 12) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)

            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(showPassword ? "Hide password" : "Show password")
                .disabled(password.isEmpty || isLoading)
            }

            HStack {
                Group {
                    if showConfirmPassword {
                        TextField("Confirm Password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm Password", text: $confirmPassword)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                
                Button {
                    showConfirmPassword.toggle()
                } label: {
                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(showConfirmPassword ? "Hide confirm password" : "Show confirm password")
                .disabled(confirmPassword.isEmpty || isLoading)
            }
        }
        .shake(shakeTrigger, amount: 6, shakesPerUnit: 2)
    }

    // MARK: - Step 2

    private var profileStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 10) {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)

                    TextField("Headline (optional)", text: $headline)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)

                    TextField("Bio (optional)", text: $bio, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(5)
                        .disabled(isLoading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Footer buttons

    private var footerButtons: some View {
        HStack(spacing: 10) {
            if step == .profile {
                Button("Back") {
                    message = nil
                    step = .account
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            Spacer()

//            if step == .profile {
//                Button("Skip") {
//                    Task { await createAccountThenSaveProfileAndLogin(skipProfile: true) }
//                }
//                .buttonStyle(.plain)
//                .foregroundStyle(.secondary)
//                .disabled(isLoading)
//            }

            Button {
                Task { await primaryAction() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Text(primaryTitle)
                }
                .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isLoading)
            .shake(shakeTrigger)
        }
    }

    private var primaryTitle: String {
        switch step {
        case .account: return "Continue"
        case .profile: return "Finish"
        }
    }

    // MARK: - Actions

    private func primaryAction() async {
        message = nil

        switch step {
        case .account:
            guard await validateAccount() else { return }
            step = .profile

        case .profile:
            await createAccountThenSaveProfileAndLogin(skipProfile: false)
        }
    }

    private func validateAccount() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if u.count < 3 {
            message = "Username must be at least 3 characters."
            shakeTrigger += 1
            return false
        }

        if u.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            message = "Please fill in username, password, and confirm password."
            shakeTrigger += 1
            return false
        }

        if password != confirmPassword {
            message = "Passwords do not match."
            shakeTrigger += 1
            return false
        }

        if password.count < 8 {
            message = "Password must be at least 8 characters."
            shakeTrigger += 1
            return false
        }
        
        do {
            let availableUsername = try await auth.validateUsername(u)
            if !availableUsername {
                message = "That username is already taken."
                shakeTrigger += 1
                return false
            }
        } catch {
            // Surface a generic error if username validation fails
            message = "Couldn't validate username. Please try again."
            shakeTrigger += 1
            return false
        }
        
        return true
    }

    private func createAccountThenSaveProfileAndLogin(skipProfile: Bool) async {
        message = nil
        isLoading = true
        defer { isLoading = false }

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await auth.signup(username: u, password: password)

            // Build profile
            var profile = UserProfile.defaultProfile(for: u)

            if !skipProfile {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmedName.isEmpty { profile.name = trimmedName }
                if !trimmedHeadline.isEmpty { profile.headline = trimmedHeadline }
                if !trimmedBio.isEmpty { profile.bio = trimmedBio }
            }

            // Persist profile immediately for this username
            let store = ProfileStore(username: u)
            store.profile = profile
            store.save()

            // Auto login
            session.login(username: u)

            // Close signup sheet
            dismiss()
        } catch {
            message = "Signup failed. Try a different username."
            shakeTrigger += 1
        }
    }

    // MARK: - Complaint UI

    private func complaintRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .foregroundStyle(.red)
                .font(.callout)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
#Preview {
    SignupView()
        .environmentObject(SessionState())
}

