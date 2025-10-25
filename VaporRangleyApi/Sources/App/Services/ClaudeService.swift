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
        
        Your goal is to gather the following information through natural conversation:
        - Event name (required)
        - Start date and time (required)
        - End date and time (required)
        - Description (optional)
        - Category ID (optional - 1-10, where 1=Social, 2=Sports, 3=Food/Drink, 4=Arts, 5=Music, 6=Outdoors, 7=Gaming, 8=Study, 9=Business, 10=Other)
        - Max capacity (optional)
        
        Location information will be provided automatically by the app.
        
        Ask clarifying questions in a conversational, friendly way. Keep responses concise (2-3 sentences max).
        
        When you have gathered all REQUIRED information (name, start time, end time), respond with ONLY a JSON object in this exact format:
        {
          "ready": true,
          "name": "string",
          "dttm_start_utc": "ISO8601 datetime string",
          "dttm_end_utc": "ISO8601 datetime string",
          "description": "string or null",
          "meet_category_id": number or null,
          "max_capacity": number or null
        }
        
        IMPORTANT: 
        - Convert all dates/times to UTC ISO8601 format (e.g., "2025-10-25T19:00:00Z")
        - If the user provides a relative time (e.g., "tomorrow at 7pm"), calculate the actual datetime
        - Current date/time context: Use today's date as reference for relative times
        - The JSON response must be valid and parseable
        - Do NOT wrap the JSON in markdown code blocks or any other formatting
        - Do NOT include any text before or after the JSON when ready=true
        
        Continue asking questions until you have name, start time, and end time.
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
