//
//  TestView.swift
//  Forge
//
//  Created by Lakshya Agarwal on 3/9/26.
//

import SwiftUI

struct TestView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var chatManager: ChatManager
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
//            Button {
//                dismiss()
//            } label: {
//                Image(systemName: "xmark")
//            }
//            .buttonStyle(.plain)
            
            // MARK: Chat
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        
                        if chatManager.messages.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.blue)
                                
                                Text("Start by describing your idea")
                                    .font(.headline)
                                
                                Text("I’ll ask a few questions to help refine it")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 380)
                            .padding(.top, 40)
                        }
                        
                        ForEach(chatManager.messages, id: \.id) { msg in
                            chatBubble(msg)
                                .id(msg.id)
                        }
                        
                        if chatManager.isSummaryReady {
                            confirmSection
                        }
                        
                        if chatManager.isLoading {
                            loadingView
                        }
                    }
                    .padding()
                }
                .onChange(of: chatManager.messages.count) { _, _ in
                    proxy.scrollTo(chatManager.messages.last?.id, anchor: .bottom)
                }
            }
            
            Divider().opacity(0.3)
            
            // MARK: Input
            inputBar
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .frame(width: 600, height: 550)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer() }
            
            Text(msg.content)
                .font(.body)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(msg.role == .user ? Color.blue.opacity(0.4) : Color.green.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.separator.opacity(0.3))
                )
                .frame(maxWidth: 360, alignment: msg.role == .user ? .trailing : .leading)
                .textSelection(.enabled)
            
            if msg.role == .ai { Spacer() }
        }
    }
    
    private var confirmSection: some View {
        VStack(spacing: 10) {
            Text("Does this match your idea?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: {
                chatManager.confirmIdea()
            }) {
                Text("Yes, this is correct ✓")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Text("If this doesn’t match, just type what’s wrong in the next message.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var loadingView: some View {
        HStack {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                
                Text("AI is thinking...")
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.separator.opacity(0.3))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Describe your idea...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                )
                .focused($isFocused)
                .onSubmit { Task { await send() } }
            
            Button(action: {
                Task { await send() }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(inputText.isEmpty ? .gray : .blue)
                    .font(.system(size: 26))
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || chatManager.isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    func send() async {
        let text = inputText
        inputText = ""
        await chatManager.send(userText: text)
    }
}
