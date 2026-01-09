//
//  SignupView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//

import SwiftUI

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    private let auth = AuthService()

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isHardMode = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 18) {
                ZStack {
                    Text("Create Account")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay(alignment: .trailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("**X**")
                            .background(Color.clear)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.clear, in: .rect(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.clear, in: .rect(cornerRadius: 12))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await handleSignup() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isLoading)
                .keyboardShortcut(.defaultAction)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(28)
    }

    private func handleSignup() async {
        errorMessage = nil
        isLoading = true
        do {
            try await auth.signup(username: username, password: password)
            dismiss()
        } catch {
            errorMessage = "Signup failed"
        }
        isLoading = false
    }
}

#Preview {
    SignupView()
        .environmentObject(SessionState())
}

