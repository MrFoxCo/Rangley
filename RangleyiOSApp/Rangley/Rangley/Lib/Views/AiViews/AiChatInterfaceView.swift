//
//  AiChatInterfaceView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import SwiftUI

struct AiChatInterfaceView: View
{
    let entryMode: MeetCreationEntryMode
    let baseURL: URL
    let token: String
    let onClose: () -> Void
    let onCreateMeet: (MeetInsertBody) async throws -> Void
    
    @State private var messageText: String = ""
    @State private var chatHistory: [ClaudeModel.ChatMessage] = []  // CHANGED
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View
    {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Welcome message
                        welcomeMessageView
                        
                        // Chat history
                        ForEach(Array(chatHistory.enumerated()), id: \.offset) { index, message in
                            ChatBubbleView(message: message)
                                .id(index)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            loadingIndicatorView
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            errorMessageView(error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatHistory.count) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue - 1, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            inputAreaView
        }
        .background(AppPalette.Brand.japDarkerPurple)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Header
    private var headerView: some View
    {
        HStack {
            // AI Icon
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Text("Let's create your meet together")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            
            Spacer()
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppPalette.Text.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Welcome Message
    private var welcomeMessageView: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                
                Text("Welcome!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
            }
            
            Text(welcomeMessageText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppPalette.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var welcomeMessageText: String {
        switch entryMode {
        case .tapOnMap:
            return "I'll help you create a meet at this location. Tell me about your event - what are you planning?"
        case .createButton:
            return "I'll help you create your meet. Tell me what kind of event you're planning!"
        case .createWithGroup(let group, _):
            return "I'll help you create a meet with \(group.name). What kind of event do you want to plan?"
        case .update:
            return "I'll help you update this meet. What changes would you like to make?"
        }
    }
    
    // MARK: - Loading Indicator
    private var loadingIndicatorView: some View
    {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppPalette.Brand.neonPink)
                    .frame(width: 8, height: 8)
                    .opacity(0.6)
                    .scaleEffect(isLoading ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isLoading
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Error Message
    private func errorMessageView(_ error: String) -> some View
    {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Input Area
    private var inputAreaView: some View
    {
        HStack(spacing: 12) {
            // Text field
            TextField("Type your message...", text: $messageText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(AppPalette.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .lineLimit(1...4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .focused($isTextFieldFocused)
                .disabled(isLoading)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                        ? AppPalette.Text.secondary.opacity(0.3)
                        : AppPalette.Brand.neonPink
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
            alignment: .top
        )
    }
    
    // MARK: - Actions
    // MARK: - Actions
    private func sendMessage()
    {
        print("DEBUG: sendMessage() called")
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("DEBUG: trimmedMessage = '\(trimmedMessage)'")
        print("DEBUG: isEmpty check = \(trimmedMessage.isEmpty)")
        
        guard !trimmedMessage.isEmpty else {
            print("DEBUG: Message was empty, returning")
            return
        }
        
        print("DEBUG: Creating user message")
        
        // Add user message to history
        let userMessage = ClaudeModel.ChatMessage(role: "user", content: trimmedMessage)
        chatHistory.append(userMessage)
        
        print("DEBUG: User message added to history. Total messages: \(chatHistory.count)")
        
        // Clear input
        messageText = ""
        errorMessage = nil
        isLoading = true
        
        print("DEBUG: Starting API call")
        print("DEBUG: baseURL = \(baseURL)")
        print("DEBUG: token exists = \(!token.isEmpty)")
        
        // Call API
        Task {
            do {
                print("DEBUG: About to call AuthAPI.postChatBot")
                
                let response = try await AuthAPI.postChatBot(
                    baseURL: baseURL,
                    token: token,
                    message: trimmedMessage,
                    history: Array(chatHistory.dropLast())
                )
                
                print("DEBUG: Got response: \(response)")
                
                await MainActor.run {
                    // Add assistant response
                    let assistantMessage = ClaudeModel.ChatMessage(role: "assistant", content: response)
                    chatHistory.append(assistantMessage)
                    isLoading = false
                    print("DEBUG: Assistant message added")
                }
                
            } catch {
                print("DEBUG: Error occurred: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to send message. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View
{
    let message: ClaudeModel.ChatMessage  // CHANGED
    
    private var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View
    {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.15))
                    )
            }
            
            // Message bubble
            Text(message.content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(isUser ? .white : AppPalette.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser
                            ? AppPalette.Brand.neonPink
                            : Color.white.opacity(0.08)
                        )
                )
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            
            if isUser {
                // User avatar placeholder
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppPalette.Text.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
