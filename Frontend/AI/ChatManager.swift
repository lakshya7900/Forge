//
//  ForgeAIManager.swift
//  Forge
//
//  Created by Lakshya Agarwal on 4/30/26.
//

import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user, ai
    }
}

@MainActor
final class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isSummaryReady = false
    @Published var summaryText = ""

    private var history: [AIManager.Message] = []

    private let systemPrompt = """
    You are Forge's idea intake assistant. Your job is to extract a clear product concept \
    from a vague idea through short, focused questions — one at a time. \
    Never ask multiple questions at once. Never add disclaimers or filler. \
    Ask only what you need to understand: what it does, who it's for, how it works, \
    what platform, what is the main usp, are their any competitors if any what sets you apart, and whether AI is involved. \
    When you have enough to summarize the idea clearly, respond with exactly this format:

    summary: So what you're building is basically a [type] that [core problem] that has [all the unique features] — \
    and the user interacts with it through a clean interface, setting their preferences \
    so the AI can do the heavy lifting for them?

    Start the response with "summary:" (lowercase, no markdown). \
    Do not add anything before or after the summary line.
    Do not truncate mid-sentence under any circumstances.
    """

    func send(userText: String) async {
        isSummaryReady = false 
        messages.append(ChatMessage(role: .user, content: userText))
        history.append(AIManager.Message(role: "user", parts: [.init(text: userText)]))
        isLoading = true
//        try? await Task.sleep(nanoseconds: 1_500_000_000)

        do {
            let response = try await AIManager.send(history: history, systemPrompt: systemPrompt)
            history.append(AIManager.Message(role: "model", parts: [.init(text: response)]))

            if response.lowercased().hasPrefix("summary:") {
                let text = String(response.dropFirst("summary:".count)).trimmingCharacters(in: .whitespaces)
                summaryText = text
                isSummaryReady = true
                messages.append(ChatMessage(role: .ai, content: text))
            } else {
                messages.append(ChatMessage(role: .ai, content: response))
            }
        } catch {
            messages.append(ChatMessage(role: .ai, content: "Something went wrong. Try again."))
        }

        isLoading = false
    }

    func confirmIdea() {
        isSummaryReady = false
        let summary = summaryText
        messages.append(ChatMessage(role: .ai, content: "Perfect. Setting up your project now..."))

        Task {
            do {
                let project = try await JSONFormatter.format(summary: summary)
                print("Project JSON: \(project)")
                // pass `project` to Model 3 / your project setup flow here
            } catch {
                print("JSON formatting failed: \(error)")
            }
        }
    }
}
