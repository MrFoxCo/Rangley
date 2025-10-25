//
//  ClaudeService.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import Vapor
import Foundation

struct ClaudeService
{
    let config: ClaudeConfig
    let client: any Client
    
    init(config: ClaudeConfig, client: any Client)
    {
        self.config = config
        self.client = client
    }
    
    /// Generate chatbot response for meet creation
    func generateChatResponse(
        userMessage: String,
        conversationHistory: [Claude.ChatMessage]?
    ) async throws -> String
    {
        
        let systemPrompt = """
        You are a helpful assistant for Rangley, a location-based meetup app.
        You're helping the user create a new meet/event.
        
        Ask clarifying questions about their event in a conversational way.
        Keep responses concise (2-3 sentences max) and friendly.
        """
        
        // Build messages array
        var messages: [[String: String]] = []
        
        // Add conversation history if exists
        if let history = conversationHistory {
            messages = history.map { ["role": $0.role, "content": $0.content] }
        }
        
        // Add current message
        messages.append(["role": "user", "content": userMessage])
        
        // Make API call
        return try await callClaudeAPI(
            systemPrompt: systemPrompt,
            messages: messages
        )
    }
    
    /// Core Claude API call
    private func callClaudeAPI(
        systemPrompt: String,
        messages: [[String: String]]
    ) async throws -> String
    {
        
        let payload: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "system": systemPrompt,
            "messages": messages
        ]
        
        // Convert payload to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let response = try await client.post(URI(string: "\(config.baseURL)/messages")) { (clientReq: inout ClientRequest) in
            clientReq.headers.add(name: "x-api-key", value: config.apiKey)
            clientReq.headers.add(name: "anthropic-version", value: config.apiVersion)
            clientReq.headers.add(name: "Content-Type", value: "application/json")
            clientReq.body = ByteBuffer(data: jsonData)
        }
        
        guard response.status == HTTPStatus.ok else {
            let errorBody = response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Claude API error: \(errorBody)")
        }
        
        let claudeResponse = try response.content.decode(ClaudeAPIResponse.self)
        
        guard let firstContent = claudeResponse.content.first else {
            throw Abort(.internalServerError, reason: "No content in Claude response")
        }
        
        return firstContent.text
    }
    
    // MARK: - Request/Response Models
    
    
    struct ClaudeAPIResponse: Content {
        let id: String
        let type: String
        let role: String
        let content: [ClaudeContent]
        let model: String
        let stop_reason: String?
        
        struct ClaudeContent: Content {
            let type: String
            let text: String
        }
    }
}

// MARK: - Request Extension (moved outside struct)
extension Request {
    var claudeService: ClaudeService {
        guard let config = application.claudeConfig else {
            fatalError("ClaudeConfig not configured. Call app.claudeConfig = try ClaudeConfig.fromEnvironment() in configure.swift")
        }
        return ClaudeService(config: config, client: client)
    }
}
