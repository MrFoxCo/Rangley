//
//  MessengerView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import SwiftUI

// MARK: - Main Messenger View
struct MessengerView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    var body: some View
    {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                    
                    Spacer()
                    
                    Text("Messages")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppPalette.Text.primary)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(AppPalette.Brand.formBlack)
                
                // Coming soon content
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
                    
                    VStack(spacing: 12) {
                        Text("Messages")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppPalette.Text.primary)
                        
                        Text("Available in future updates")
                            .font(.system(size: 16))
                            .foregroundStyle(AppPalette.Text.secondary)
                        
                        Text("Chat with friends and coordinate meets in real-time")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.Text.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppPalette.Brand.formBlack)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Messenger Header
private struct MessengerHeader: View
{
    let selectedConversation: Conversation?
    let onDismiss: () -> Void
    
    var body: some View
    {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
            }
            
            Spacer()
            
            Text(selectedConversation?.title ?? "Messages")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            // Invisible spacer for centering
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.system(size: 16, weight: .medium))
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(AppPalette.Brand.formBlack)
    }
}



// MARK: - Conversation Button
private struct ConversationButton: View
{
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void
    
    private var initials: String {
        String(conversation.title.prefix(1)).uppercased()
    }
    
    var body: some View
    {
        Button(action: onTap) {
            ZStack {
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        isSelected ? AppPalette.Brand.neonPink : AppPalette.Text.primary
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? AppPalette.Brand.neonPink.opacity(0.2)
                                    : AppPalette.Brand.japPurple
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected
                                    ? AppPalette.Brand.neonPink.opacity(0.8)
                                    : AppPalette.Brand.neonPink.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                
                // Unread badge (if applicable)
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(Color.red))
                        .offset(x: 16, y: -16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat View
private struct ChatView: View
{
    let conversation: Conversation
    let baseURL: URL
    let token: String
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = false
    
    var body: some View
    {
        VStack(spacing: 0) {
            // Messages list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(AppPalette.Text.tertiary)
                            
                            Text("No messages yet")
                                .font(.system(size: 16))
                                .foregroundStyle(AppPalette.Text.secondary)
                            
                            Text("Start the conversation!")
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.Text.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .padding(20)
            }
            
            // Message input
            MessageInputBar(
                text: $messageText,
                onSend: sendMessage
            )
        }
        .task {
            await loadMessages()
        }
    }
    
    private func loadMessages() async
    {
        isLoading = true
        
        // TODO: Load messages from API
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        await MainActor.run {
            messages = [] // Placeholder
            isLoading = false
        }
    }
    
    private func sendMessage()
    {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // TODO: Send message via API
        messageText = ""
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View
{
    let message: ChatMessage
    
    var body: some View
    {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.secondary)
                }
                
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(message.isFromCurrentUser ? .white : AppPalette.Text.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                message.isFromCurrentUser
                                    ? AppPalette.Brand.neonPink
                                    : AppPalette.Surface.fieldFill
                            )
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.Text.tertiary)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

// MARK: - Message Input Bar
private struct MessageInputBar: View
{
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View
    {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.Text.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppPalette.Surface.fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                )
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppPalette.Text.tertiary
                            : AppPalette.Brand.neonPink
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppPalette.Brand.formBlack)
    }
}

// MARK: - Empty Placeholders
private struct EmptyChatPlaceholder: View
{
    var body: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            Text("Select a conversation")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoadingPlaceholder: View
{
    var body: some View
    {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Models (Placeholder)
struct Conversation: Identifiable
{
    let id: String
    let title: String
    let lastMessage: String?
    let timestamp: Date
    let unreadCount: Int
    let isGroup: Bool
}

struct ChatMessage: Identifiable
{
    let id: String
    let text: String
    let senderName: String
    let senderId: String
    let timestamp: Date
    let isFromCurrentUser: Bool
}
