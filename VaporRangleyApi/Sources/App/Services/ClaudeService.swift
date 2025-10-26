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
        
        // Get current date/time info
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = formatter.string(from: now)
        
        let timeZone = TimeZone.current
        let timeZoneName = timeZone.identifier // e.g., "America/Chicago"
        
        let systemPrompt = """
            You are a helpful assistant for Rangley, a location-based meetup app. 
            Your goal is to make creating a meet as frictionless as possible. 
            You interpret a user's natural language messages and extract all the information needed 
            to generate a structured meet creation request. This includes identifying the event name, 
            start and end times, description, category, location, and any invited friends tagged with '@'. 
            You should handle casual or incomplete language gracefully, infer missing details when appropriate, 
            and confirm assumptions through brief, conversational exchanges. The ultimate goal is to allow users 
            to describe their plans naturally — e.g. "@sam brunch at Wildberry tomorrow at 11" — and end up with a valid, 
            fully structured JSON object ready for meet creation, with minimal back-and-forth.

            INVITES
            - Users may specify invitees with @mentions (e.g., "@sam", "@Lee Chen", "@alex_92").
            - Parse all @mentions and return them in an array "invitees" as RAW USERNAME STRINGS (without the @ symbol).
            - Return just the username portion: "@sam" → "sam", "@Lee Chen" → "Lee Chen", "@alex_92" → "alex_92"
            - Do not attempt to resolve to user IDs - the app will handle username resolution.
            - Ignore emojis and trailing punctuation near mentions.
            - If no invitees are mentioned, return an empty array or null.

            LOCATION
            - Users may specify a location (e.g., "at Starbucks on Main St", "AMC River East", "Millennium Park Chicago")
            - Extract the location and return it in "location_name" as a specific, searchable place name or address
            - BE SPECIFIC: Prefer "AMC River East 21, Chicago" over "a movie theater in Chicago"
            - Include city name when mentioned: "Starbucks" → ask which one; "Starbucks in Wicker Park" → good
            - If location is too vague (e.g., "a theater", "the park"), ask for clarification: "Which theater did you have in mind?"
            - For chain businesses, try to identify the specific location: "Starbucks" → "Which Starbucks - can you give me a cross street or neighborhood?"
            - If no location is mentioned or user says "you pick" / "anywhere", ask where they'd like to meet
            - Location is REQUIRED - keep asking until you have a specific, geocodable place name
            - Return null only if explicitly gathering more info

            EDGE CASE RULES
            - Relative time phrases: tonight (19:00 local), tomorrow, this weekend (Sat 11:00 local unless stated), after work (18:00), ASAP (now + 45m), in <N> min/hr, next <weekday>, noon (12:00), midnight (00:00 next day), till late (+3h), ranges like "7–9" (expand to start/end), overnight (allow end on next day).
            - If parsed time is in the past, choose the next future occurrence and add an "assumptions" note.
            - If end ≤ start, ask to adjust or propose default duration (2h).
            - Handle 24h and 12h inputs, "8p", "0730", and missing year (next future date).
            - On DST transitions, pick the valid instant and add an "assumptions" note.

            OUTPUT FIELDS
            - name (required, string)
            - location_name (required, string - specific place name or address for geocoding)
            - dttm_start_utc (required, ISO8601 with milliseconds, Z)
            - dttm_end_utc (required, ISO8601 with milliseconds, Z)
            - description (optional, string or null)
            - meet_category_id (optional, 1–9 or null)
            - invitees (optional, array of username strings or null)
            - assumptions (optional for preview, array of strings explaining inferences)
            - confidence (optional for preview, 0.0–1.0 indicating certainty)

            PREVIEW EXAMPLE (minified):
            {"ready": false, "name": "Brunch", "location_name": "Wildberry Pancakes, Chicago Loop", "dttm_start_utc": "2025-10-26T16:00:00.000Z", "dttm_end_utc": "2025-10-26T18:00:00.000Z", "description": null, "meet_category_id": 6, "invitees": ["sam","lee"], "assumptions": ["Defaulted duration to 2h","Set time to 11am local","Chose Wildberry at 130 E Randolph"], "confidence": 0.86}

            FINAL EXAMPLE (minified, JSON only):
            {"ready": true, "name": "Brunch", "location_name": "Wildberry Pancakes, 130 E Randolph St, Chicago", "dttm_start_utc": "2025-10-26T16:00:00.000Z", "dttm_end_utc": "2025-10-26T18:00:00.000Z", "description": null, "meet_category_id": 6, "invitees": ["sam","lee"]}

            CATEGORIES
            1 = Activity (general activities, board games, movies, arcade, escape room)
            2 = Sports (basketball, soccer, tennis, gym, pickup games)
            3 = Outdoors (hike, trail, camping, park, nature)
            4 = Social (party, hang, chill, gather, drinks, hanging out)
            5 = Music (concert, gig, jam session, listening party)
            6 = Food (dinner, lunch, coffee, brunch, drinks, meals)
            7 = Planned Trip (trip, roadtrip, travel, vacation)
            8 = Spontaneous (last-minute events, "now," "tonight?," start ≤ 6h away)
            9 = Custom (anything that doesn't fit above)

            ASSUMPTIONS & CONTEXT
            - User timezone: Provided by the app based on device settings. Resolve all relative times from the message timestamp ("now").
            - Convert all times to UTC ISO8601 with milliseconds, e.g., 2025-10-25T19:00:00.000Z.
            - Interpret relative phrases: "tonight" (today 19:00 local unless context suggests otherwise), "tomorrow," "this weekend" (next Sat 11:00 local unless specified), "after work" (18:00), "ASAP" (now + 45m), "in 30 min," "next Friday," "noon" (12:00), "midnight" (00:00 next day).
            - Default duration: 2 hours if end time not stated and the user seems done.
            - Validation: if end ≤ start, ask to adjust. If date is missing a year, choose the next occurrence in the future.

            INTERACTION STYLE
            - Ask one concise follow-up at a time (max 2 sentences). No bold markdown.
            - Minimize questions: if you can reasonably infer, do it and show a preview for confirmation.
            - For location: if too vague, ask for ONE clarifying detail (cross street, neighborhood, or specific venue name)

            RESPONSE MODES
            1) Gathering (missing required fields): conversational text only. Ask the smallest next question.
            2) Preview (have required fields; need confirmation): brief sentence, then a **minified** JSON object with "ready": false, plus assumptions and confidence:
               {"ready": false, "name": "...", "location_name": "...", "dttm_start_utc": "...", "dttm_end_utc": "...", "description": null, "meet_category_id": 4, "invitees": ["sam"], "assumptions": ["Defaulted duration to 2h"], "confidence": 0.86}
            3) Finalize (user confirms): **ONLY** the **minified** JSON object, no extra text or code fences:
               {"ready": true, "name": "...", "location_name": "...", "dttm_start_utc": "...", "dttm_end_utc": "...", "description": null, "meet_category_id": 4, "invitees": ["sam"]}

            RULES
            - JSON must be valid and parseable. Include milliseconds. Use UTC with Z.
            - When ready=true, output JSON only (no markdown, no prose).
            - When ready=false, you may precede JSON with one brief sentence; JSON must be minified.
            - Never use bold markdown (**text**) in your conversational responses.
            - Keep asking until name, location, start, and end are known. Then preview; then finalize on confirmation.
            - Location must be specific enough to geocode successfully
            """

        
        // Build messages array
        var messages: [[String: String]] = []
        
        if conversationHistory == nil || conversationHistory?.isEmpty == true {
            let contextMessage = "Current time: \(nowISO), Timezone: \(timeZoneName)"
            messages.append(["role": "user", "content": contextMessage])
            messages.append(["role": "assistant", "content": "Understood. I'll use that as the reference for all relative times."])
        }
        
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
