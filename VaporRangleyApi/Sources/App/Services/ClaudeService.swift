//
//  ClaudeService.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import Vapor
import Foundation
import RegexBuilder

// MARK: - PlaidError

/// Plaid-specific errors for meetup agent pipeline
enum PlaidError: Error, CustomStringConvertible, Equatable {
    case invalidJSON(details: String)
    case missingRequired(fields: [String])
    case invalidTime(details: String)
    case modelBrokeRules(violation: String)
    case noValidLocation
    case finalizeWithoutPreview
    case geocodeFailed
    case `internal`(String)

    var description: String {
        switch self {
        case .invalidJSON(let details):          return "PLAID: Invalid JSON — \(details)"
        case .missingRequired(let fields):       return "PLAID: Missing required — \(fields.joined(separator: ", "))"
        case .invalidTime(let details):          return "PLAID: Invalid time — \(details)"
        case .modelBrokeRules(let violation):   return "PLAID: Model violated rules — \(violation)"
        case .noValidLocation:                  return "PLAID: No geocodable location provided"
        case .finalizeWithoutPreview:           return "PLAID: User confirmed but no preview state"
        case .geocodeFailed:                    return "PLAID: Geocoding failed for location"
        case .internal(let msg):                return "PLAID: Internal — \(msg)"
        }
    }

    var analyticsCode: String {
        switch self {
        case .invalidJSON:      return "json_invalid"
        case .missingRequired:  return "req_missing"
        case .invalidTime:      return "time_invalid"
        case .modelBrokeRules:  return "rule_break"
        case .noValidLocation:  return "loc_none"
        case .finalizeWithoutPreview: return "finalize_no_state"
        case .geocodeFailed:    return "geocode_fail"
        case .internal:         return "internal"
        }
    }
}

// MARK: - ClaudeService

struct ClaudeService {
    let config: ClaudeConfig
    let client: any Client
    
    init(config: ClaudeConfig, client: any Client) {
        self.config = config
        self.client = client
    }

    // MARK: Public API

    /// Generate chatbot response for meet creation — PLAID+ MODE WITH AGGRESSIVE EXTRACTION
    func generateChatResponse(
        userMessage: String,
        conversationHistory: [Claude.ChatMessage]?,
        currentTimeNatural: String,      // NOW REQUIRED
        userTimezone: String,            // NOW REQUIRED
        userLocation: String,            // NOW REQUIRED
        userDisplayName: String,         // NOW REQUIRED
        tapLocation: Claude.TapLocationContext?
    ) async throws -> String {

        // 1. CONTEXT BLOCK - ALWAYS AVAILABLE
        var contextLines: [String] = [
            "- Current time: \(currentTimeNatural)",
            "- User timezone: \(userTimezone)",
            "- User is currently near: \(userLocation)",
            "- User's name: \(userDisplayName)"
        ]
        
        if let tap = tapLocation {
            if let name = tap.name, !name.isEmpty {
                contextLines.append("- User tapped on map at: \(name) (\(tap.latitude), \(tap.longitude))")
            } else {
                contextLines.append("- User tapped on map at coordinates: (\(tap.latitude), \(tap.longitude))")
            }
        }

        let contextBlock = """
        CURRENT CONTEXT (ALWAYS FRESH):
        \(contextLines.joined(separator: "\n"))
        
        """

        // 2. AGGRESSIVE EXTRACTION PROMPT
        let systemPrompt = contextBlock + """
        NOW: \(currentTimeNatural) (\(userTimezone))
        
        ⚠️ CRITICAL PARSING RULES - READ FIRST ⚠️
        
        1. EXTRACT ALL INFORMATION from EVERY message - users provide compound data
        2. NEVER re-ask for information already provided in current or previous messages
        3. CHECK THE CONVERSATION HISTORY before asking questions
        4. If you have ALL REQUIRED FIELDS → GO TO PREVIEW MODE IMMEDIATELY
        
        COMPOUND INPUT PATTERNS - RECOGNIZE AND EXTRACT:
        
        • "[event] at [location]" → extract BOTH name AND location
          Example: "party at 1318 n cleveland" 
          → name: "Party", location_name: "1318 N Cleveland Ave, Chicago, IL"
        
        • "[event] at [location] [time]" → extract ALL THREE
          Example: "brunch at wildberry tomorrow at 10am" 
          → name: "Brunch", location_name: "Wildberry", start: tomorrow 10:00
        
        • "[event] at [location] [time] for [duration]" → extract ALL FOUR
          Example: "party at 1318 n cleveland tomorrow at 2pm for an hour"
          → name: "Party", location_name: "1318 N Cleveland Ave", start: tomorrow 14:00, end: tomorrow 15:00
        
        • "surprise [event]" → include "Surprise" in the name
          Example: "surprise tennis match" → name: "Surprise Tennis Match"
        
        • Address patterns (numbers + street names) → ALWAYS use as location_name
          Example: "1318 n cleveland" → location_name: "1318 N Cleveland Ave, Chicago, IL"
          Example: "3703 greenview" → location_name: "3703 N Greenview Ave, Chicago, IL"
        
        • Time + duration in one phrase → calculate both
          Example: "tomorrow at 2pm for an hour" → start: tomorrow 14:00, end: tomorrow 15:00
          Example: "tonight for 2 hours" → start: tonight 19:00, end: tonight 21:00
        
        COMPLETE EXAMPLE OF WHAT YOU SHOULD DO:
        User: "Let's make a party at 1318 n cleveland in chicago tomorrow at 2pm for an hour please"
        
        You extract:
        ✓ name: "Party"
        ✓ location_name: "1318 N Cleveland Ave, Chicago, IL"
        ✓ dttm_start_utc: [calculate tomorrow at 14:00 in \(userTimezone) → convert to UTC with .000Z]
        ✓ dttm_end_utc: [calculate tomorrow at 15:00 in \(userTimezone) → convert to UTC with .000Z]
        
        → ALL REQUIRED FIELDS FILLED → GO TO PREVIEW MODE IMMEDIATELY
        → DO NOT ASK "WHAT KIND OF MEETUP?" - YOU ALREADY KNOW IT'S A PARTY
        
        TIME PARSING RULES:
        - Current time is: \(currentTimeNatural)
        - Never create events in the past
        - "tomorrow" → add 1 day to current date
        - "tomorrow at 2pm" → tomorrow's date at 14:00 in \(userTimezone)
        - "for an hour" / "for 1 hour" → endTime = startTime + 1 hour
        - "for 2 hours" → endTime = startTime + 2 hours
        - "tonight" → today at 19:00
        - "this weekend" → next Saturday at 11:00
        - "7-9pm" → start: 19:00, end: 21:00
        - "noon" → 12:00, "midnight" → 00:00 next day
        - No time specified → default to 18:00 (6 PM)
        - No end time specified → default to start + 2 hours
        
        LOCATION PARSING RULES:
        - Street addresses → format as full address with city
          "1318 n cleveland" → "1318 N Cleveland Ave, Chicago, IL"
          "3703 greenview" → "3703 N Greenview Ave, Chicago, IL"
        - Venue names → use as-is
          "millennium park" → "Millennium Park, Chicago, IL"
          "wildberry" → "Wildberry Pancakes & Cafe"
        - If user tapped map → prefer tap location
        - Add "Chicago, IL" to addresses if city not specified (user is in Chicago)
        - Vague locations ("somewhere", "TBD") → ask for clarification
        
        REQUIRED FIELDS:
        1. name: string (2-50 characters, trimmed)
           • Extract from user's message
           • "party" → "Party"
           • "brunch" → "Brunch"
           • "surprise tennis" → "Surprise Tennis Match"
        
        2. location_name: geocodable address or venue (max 100 characters)
           • Must be specific enough to geocode
           • Extract from "at [location]" pattern
        
        3. dttm_start_utc: ISO8601 with milliseconds and Z
           • Format: "2025-10-28T19:00:00.000Z"
           • MUST be in the future
           • Convert from \(userTimezone) to UTC
           • ALWAYS include .000Z at the end
        
        4. dttm_end_utc: ISO8601, must be > start
           • Calculate from duration if provided
           • Default: start + 2 hours if not specified
           • Max duration: 24 hours
           • ALWAYS include .000Z at the end
        
        OPTIONAL FIELDS:
        - description: string | null (max 200 chars, trimmed)
        - meet_category_id: 1-9 | null
          1=Activity 2=Sports 3=Outdoors 4=Social 5=Music 6=Food 7=Planned Trip 8=Spontaneous 9=Custom
        - invitees: array of @mentions (strip @ symbol) | null
          Example: ["sam", "alex"] from "@sam @alex"
        - assumptions: array of inferences made
          Example: ["Duration set to 2 hours", "Category inferred as Social", "Added Chicago to address"]
        - confidence: 0.0-1.0
        
        DATA VALIDATION:
        - Trim all string fields
        - Empty strings → null
        - ALL timestamps MUST include .000Z
        - name must be 2-50 chars
        - description must be 0-200 chars or null
        - meet_category_id must be 1-9 or null
        
        RESPONSE MODES:
        
        1. GATHERING MODE (missing required fields that user HASN'T mentioned):
           → Ask ONE short question (≤2 sentences)
           → NO JSON
           → NO bold formatting
           → ONLY ask if info is ACTUALLY missing after checking history
           → DO NOT ask for info the user already gave you
           
           Example:
           "What time works for you?"
        
        2. PREVIEW MODE (all 4 required fields filled):
           → Brief natural confirmation + minified JSON with ready: false
           
           Example:
           Perfect! I've got a party scheduled for tomorrow at 2pm at 1318 N Cleveland Ave.
           {"ready":false,"name":"Party","location_name":"1318 N Cleveland Ave, Chicago, IL","dttm_start_utc":"2025-10-29T19:00:00.000Z","dttm_end_utc":"2025-10-29T20:00:00.000Z","description":null,"meet_category_id":4,"invitees":null,"assumptions":["Duration set to 1 hour","Category set to Social","Added Chicago to address"],"confidence":0.95}
        
        3. FINALIZE MODE (user confirms with "yes", "looks good", "create it", etc.):
           → JSON ONLY with ready: true
           → NO text before or after
           
           Example:
           {"ready":true,"name":"Party","location_name":"1318 N Cleveland Ave, Chicago, IL","dttm_start_utc":"2025-10-29T19:00:00.000Z","dttm_end_utc":"2025-10-29T20:00:00.000Z","description":null,"meet_category_id":4,"invitees":null,"assumptions":["Duration set to 1 hour","Category set to Social","Added Chicago to address"],"confidence":0.95}
        
        CRITICAL REMINDERS:
        - Extract ALL information from EACH message
        - NEVER ask for info the user already gave you
        - Recognize compound patterns like "party at [location] tomorrow at [time] for [duration]"
        - If you have name + location + time → GO TO PREVIEW MODE
        - Be conversational but DECISIVE
        - Don't apologize excessively
        - JSON must be valid and minified (no newlines in the JSON itself)
        - ALWAYS include .000Z in timestamps
        """

        // 3. BUILD MESSAGES WITH HISTORY
        var messages: [[String: String]] = []
        if let history = conversationHistory {
            messages = history.map { ["role": $0.role, "content": $0.content] }
        }
        messages.append(["role": "user", "content": userMessage])

        // 4. CALL CLAUDE
        let rawResponse = try await callClaudeAPI(
            systemPrompt: systemPrompt,
            messages: messages
        )

        // 5. VALIDATE & RETURN
        return try await validateAndNormalizeResponse(
            raw: rawResponse,
            userMessage: userMessage,
            tapLocation: tapLocation,
            history: conversationHistory ?? []
        )
    }

    // MARK: Response Validation

    private func validateAndNormalizeResponse(
        raw: String,
        userMessage: String,
        tapLocation: Claude.TapLocationContext?,
        history: [Claude.ChatMessage]
    ) async throws -> String {

        // ── STEP 1: FINALIZE (ready=true) ───────────────────────────────────
        if let jsonStr = extractJSON(from: raw),
           let data = jsonStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["ready"] as? Bool == true {
            return jsonStr  // Return pure JSON for finalize
        }

        // ── STEP 2: USER CONFIRMATION → FORCE FINALIZE ──────────────────────
        let confirmWords = ["yes", "yep", "yeah", "correct", "looks good", "perfect", "create it", "make it", "confirm"]
        if confirmWords.contains(where: { userMessage.lowercased().contains($0) }) {
            return try forceFinalizeFromHistory(history: history)
        }

        // ── STEP 3: GATHERING (no JSON) ──────────────────────────────────────
        if extractJSON(from: raw) == nil {
            return raw  // Pure text response
        }

        // ── STEP 4: PREVIEW (ready=false) ────────────────────────────────────
        guard let jsonStr = extractJSON(from: raw),
              let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaidError.invalidJSON(details: "Could not parse JSON")
        }

        // Validate required fields
        let required = ["name", "location_name", "dttm_start_utc", "dttm_end_utc"]
        let missing = required.filter { json[$0] == nil || (json[$0] as? String)?.isEmpty == true }
        
        if !missing.isEmpty {
            throw PlaidError.missingRequired(fields: missing)
        }

        // Validate timestamps
        guard let startStr = json["dttm_start_utc"] as? String,
              let endStr = json["dttm_end_utc"] as? String,
              let start = isoDate(from: startStr),
              let end = isoDate(from: endStr) else {
            throw PlaidError.invalidTime(details: "Invalid ISO8601 timestamps")
        }

        if start < Date() {
            throw PlaidError.invalidTime(details: "Start time is in the past")
        }

        if end <= start {
            throw PlaidError.invalidTime(details: "End time must be after start time")
        }

        // Valid preview - return as-is
        return raw
    }

    // MARK: JSON Extraction

    private func extractJSON(from text: String) -> String? {
        // Find the first '{' and match braces to find the complete JSON object
        guard let firstBrace = text.firstIndex(of: "{") else { return nil }
        
        var braceCount = 0
        var inString = false
        var escapeNext = false
        
        for (offset, char) in text[firstBrace...].enumerated() {
            if escapeNext {
                escapeNext = false
                continue
            }
            
            if char == "\\" {
                escapeNext = true
                continue
            }
            
            if char == "\"" {
                inString.toggle()
                continue
            }
            
            if !inString {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        let endIndex = text.index(firstBrace, offsetBy: offset + 1)
                        return String(text[firstBrace..<endIndex])
                    }
                }
            }
        }
        
        return nil
    }

    // MARK: Force Finalize from History

    private func forceFinalizeFromHistory(history: [Claude.ChatMessage]) throws -> String {
        for msg in history.reversed() {
            if msg.role == "assistant",
               let jsonStr = extractJSON(from: msg.content),
               let data = jsonStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["ready"] as? Bool == false {
                var mutable = json
                mutable["ready"] = true
                mutable["assumptions"] = (mutable["assumptions"] as? [String] ?? []) + ["User confirmed"]
                let updated = try JSONSerialization.data(
                    withJSONObject: mutable,
                    options: [.withoutEscapingSlashes, .sortedKeys]
                )
                return String(data: updated, encoding: .utf8)!
            }
        }
        throw PlaidError.finalizeWithoutPreview
    }

    // MARK: ISO Helpers

    private func isoDate(from string: String?) -> Date? {
        guard let s = string else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: s)
    }

    // MARK: Claude API Call

    private func callClaudeAPI(
        systemPrompt: String,
        messages: [[String: String]]
    ) async throws -> String {

        let payload: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "system": systemPrompt,
            "messages": messages
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        let response = try await client.post(URI(string: "\(config.baseURL)/messages")) { req in
            req.headers.add(name: "x-api-key", value: config.apiKey)
            req.headers.add(name: "anthropic-version", value: config.apiVersion)
            req.headers.add(name: "Content-Type", value: "application/json")
            req.body = ByteBuffer(data: jsonData)
        }

        guard response.status == .ok else {
            let body = response.body?.getString(at: 0, length: response.body?.readableBytes ?? 0) ?? "Unknown"
            throw Abort(.badRequest, reason: "Claude API error: \(body)")
        }

        let claudeResponse = try response.content.decode(ClaudeAPIResponse.self)

        guard let first = claudeResponse.content.first else {
            throw Abort(.internalServerError, reason: "No content in Claude response")
        }

        return first.text
    }

    // MARK: - Request/Response Models

    struct ClaudeAPIResponse: Content
    {
        let id          : String
        let type        : String
        let role        : String
        let content     : [ClaudeContent]
        let model       : String
        let stop_reason : String?
        
        struct ClaudeContent: Content
        {
            let type    : String
            let text    : String
        }
    }
}

// MARK: - Request Extension

extension Request {
    var claudeService: ClaudeService {
        guard let cfg = application.claudeConfig else {
            fatalError("ClaudeConfig not configured. Call app.claudeConfig = try ClaudeConfig.fromEnvironment() in configure.swift")
        }
        return ClaudeService(config: cfg, client: client)
    }
}
