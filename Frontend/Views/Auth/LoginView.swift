//
//  LoginView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import SwiftUI

struct LoginView: View {
    @Environment(SessionState.self) private var session
    
    private let auth = AuthService()
    private let profileService = ProfileService()

    @State private var username = ""
    @State private var password = ""
    
    @State private var isLoading = false
    @State private var showSignup = false
    
    @State private var complaint: String? = nil
    @State private var shakeTrigger: Int = 0
    
    @State private var showPassword = false

    @FocusState private var focusedField: Field?
    enum Field { case username, password }

    var body: some View {
        VStack(spacing: 18) {

            VStack(spacing: 6) {
                Text("Forge")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
            .padding(.bottom, 6)

            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .username)
                        .disabled(isLoading)
                        .onSubmit { focusedField = .password }

                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .disabled(isLoading)
                        .onSubmit { Task { await handleLogin() } }
                        
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
                        .onChange(of: showPassword) { _, _ in
                            focusedField = .password
                        }
                    }
                }

                if let complaint {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(complaint)
                            .foregroundStyle(.red)
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    attemptLogin()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                        Text("Log In")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .shake(shakeTrigger)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.snappy, value: isLoading)
                .disabled(isLoading)

                Button {
                    showSignup = true
                } label: {
                    Text("Create account")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(isLoading)
                .padding(.top, 4)
            }
            .padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .padding(32)
        .frame(width: 420)
        .onAppear { focusedField = .username }
        .sheet(isPresented: $showSignup) {
            SignupView()
                .environment(session)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.resizes)
        }
    }

    // MARK: - Main Login functionality
    private func handleLogin() async {
        complaint = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let authResp = try await auth.login(username: trimmed, password: password)
            
            // Fetch profile info from DB
            let profile = try await profileService.getProfile(token: authResp.token)
            
            session.login(userID: authResp.userId, username: profile.username, token: authResp.token)
        } catch {
            complaint = "Invalid username or password."
            shakeTrigger += 1
        }
    }
    
    private func attemptLogin() {
        complaint = nil

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password

        guard !u.isEmpty, !p.isEmpty else {
            complaint = "Please enter your username and password."
            shakeTrigger += 1
            return
        }

        Task { await handleLogin() }
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0)
        )
    }
}

extension View {
    func shake(_ trigger: Int, amount: CGFloat = 10, shakesPerUnit: CGFloat = 3) -> some View {
        self.modifier(ShakeEffect(amount: amount, shakesPerUnit: shakesPerUnit, animatableData: CGFloat(trigger)))
            .animation(.snappy(duration: 0.35), value: trigger)
    }
}

#Preview {
    LoginView()
        .environment(SessionState())
}
