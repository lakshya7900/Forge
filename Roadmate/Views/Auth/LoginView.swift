//
//  LoginView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionState
    private let auth = AuthService()

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSignup = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Roadmate")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Button {
              Task { await handleLogin() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .disabled(isLoading)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 10))


            Button("Create account") {
                showSignup = true
            }
//            .buttonStyle(.link)
        }
        .padding(32)
        .frame(width: 360)
        .sheet(isPresented: $showSignup) {
            SignupView()
            // Use a partial detent to enable the floating glass effect
            .presentationDetents([.medium, .large])
            // Allows content to peek from behind on iOS 26
            .presentationContentInteraction(.resizes)
        }
    }

    private func handleLogin() async {
        errorMessage = nil
        isLoading = true
        do {
            try await auth.login(username: username, password: password)
            session.login(username: username)
        } catch {
            errorMessage = "Invalid username or password"
        }
        isLoading = false
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionState())
}
