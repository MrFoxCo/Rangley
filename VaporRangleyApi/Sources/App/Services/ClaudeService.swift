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

    /// Generate chatbot response for meet creation — PLAID+ MODE
    func generateChatResponse(
        userMessage         : String,
        conversationHistory : [Claude.ChatMessage]?,
        currentTimeNatural  : String?,
        userTimezone        : String?,
        userLocation        : String?,
        userDisplayName     : String?,
        tapLocation         : Claude.TapLocationContext?
    ) async throws -> String {

        // 1. CONTEXT BLOCK
        let contextLines: [String] = [
            currentTimeNatural.map { "- Current time: \($0)" },
            userTimezone.map { "- User timezone: \($0)" },
            userLocation.map { "- User is currently near: \($0)" },
            userDisplayName.map { "- User's name: \($0)" },
            tapLocation.map { loc in
                if let name = loc.name, !name.isEmpty {
                    return "- User tapped on map at: \(name) (\(loc.latitude), \(loc.longitude))"
                } else {
                    return "- User tapped on map at coordinates: (\(loc.latitude), \(loc.longitude))"
                }
            }
        ].compactMap { $0 }

        let contextBlock = contextLines.isEmpty ? "" : """
           CURRENT CONTEXT:
           \(contextLines.joined(separator: "\n"))
           
           """

        // 2. PLAID+ PROMPT — Clear, robust, scannable
        let systemPrompt = contextBlock + """
        NOW: \(currentTimeNatural ?? "unknown") (\(userTimezone ?? "UTC"))

        TIME RULES:
        - Never create events in the past
        - All relative times → next future occurrence
        - "yesterday" → ask: "Did you mean next week?"
        - "tomorrow" → 18:00 if no time given
        - "tonight" → 19:00 today
        - "this weekend" → Saturday 11:00
        - "after work" → 18:00 today
        - "ASAP" → now + 45 min, but only 08:00–22:00 local; else 08:00 next day
        - "7-9" → start 19:00, end 21:00
        - "noon" → 12:00, "midnight" → 00:00 next day
        - If end ≤ start → default end = start + 2h, add to assumptions

        REQUIRED:
        1. name: string (e.g., "Brunch")
           • MAX 50 characters
           • MIN 2 characters
           • No leading/trailing whitespace
           • If user input is too long, truncate intelligently or ask for shorter version
        2. location_name: geocodable address or venue
           • MAX 100 characters
           • Must be specific enough to geocode
           • Vague? Ask once: "Which [venue]?" or "What's the address?"
        3. dttm_start_utc: ISO8601 with ms + Z (e.g., 2025-10-28T16:00:00.000Z)
           • MUST be in the future
        4. dttm_end_utc: > start, default +2h
           • MUST be after start
           • MAX duration: 24 hours (if longer, ask for clarification)

        OPTIONAL:
        - description: string | null
          • MAX 200 characters
          • If user provides longer text, summarize key details
          • No leading/trailing whitespace
        - meet_category_id: 1–9 | null
          1=Activity 2=Sports 3=Outdoors 4=Social 5=Music 6=Food 7=Planned Trip 8=Spontaneous 9=Custom
          • MUST be integer between 1-9 or null
          • Invalid category → default to 9 (Custom)
        - invitees: ["sam"] | null → only @mentions, strip @
          • MAX 20 invitees per meet
          • Each username MAX 30 characters
          • Strip @ symbol and whitespace
          • Lowercase preferred
        - assumptions: [] → list all inferences
          • Each assumption MAX 100 characters
        - confidence: 0.0–1.0
          • Must be decimal between 0.0 and 1.0

        PARSE:
        - 12h or 24h, "8p", "0730", "8pm"
        - No year → next future
        - "7-9pm" → start=19:00, end=21:00

        COMPOUND RESPONSES:
        - User may provide MULTIPLE pieces of info in one message
        - Examples: "a surprise party at 1318 n cleveland", "brunch tomorrow at 10am at Wildberry"
        - ALWAYS extract ALL information from each message:
          • Event type/name (before "at" or standalone)
          • Location (after "at", "in", or address patterns)
          • Time (tomorrow, tonight, specific times)
        - Do NOT re-ask questions already answered in the current or previous messages
        - Common patterns to recognize:
          • "[event] at [location]" → extract both
          • "[event] at [location] at [time]" → extract all three
          • "[location]" alone when asking about location → use as location_name
        - Update ALL fields that user provides, even if given in unexpected order

        DATA VALIDATION RULES:
        - Trim all string fields before outputting JSON
        - Ensure name fits in 50 chars (truncate or abbreviate if needed)
        - Ensure description fits in 200 chars (summarize if needed)
        - Never output empty strings - use null instead
        - max_capacity: must be -1 (unlimited) or >= 2
        - All timestamps MUST include milliseconds (.000Z)
        - Location must be real and geocodable (not "TBD" or "anywhere")

        RESPONSE MODES:
        1. GATHERING (missing required):
           → 1 short question (≤2 sentences). No JSON. No bold.

        2. PREVIEW (all required filled):
           → "Here's your meetup:" + minified JSON (ready: false)
           {"ready":false,"name":"Brunch","location_name":"Wildberry, 130 E Randolph","dttm_start_utc":"2025-10-28T16:00:00.000Z","dttm_end_utc":"2025-10-28T18:00:00.000Z","description":null,"meet_category_id":6,"invitees":["sam"],"assumptions":["+2h duration"],"confidence":0.94}

        3. FINALIZE (user confirms):
           → JSON only (ready: true). No text.
           {"ready":true,"name":"Brunch",...}

        VALIDATION:
        - Start > now
        - End > start
        - End - Start <= 24 hours
        - name: 2-50 chars, trimmed
        - description: 0-200 chars, trimmed, or null
        - location_name must be geocodable and specific
        - JSON must be valid, minified
        - All string fields must be trimmed
        - Empty strings → null
        """

        // 3. MESSAGES
        var messages: [[String: String]] = []
        if let history = conversationHistory {
            messages = history.map { ["role": $0.role, "content": $0.content] }
        }
        messages.append(["role": "user", "content": userMessage])

        // 4. CALL CLAUDE
        let rawResponse: String
        do {
            rawResponse = try await callClaudeAPI(systemPrompt: systemPrompt, messages: messages)
        } catch {
            await logPlaidError(PlaidError.internal("Claude API failed: \(error)"))
            return "Sorry, I'm having trouble connecting. Try again?"
        }

        // 5. POST-PROCESSING WITH FULL ERROR RECOVERY
        do {
            return try await postProcessPlaidResponse(
                raw: rawResponse,
                userMessage: userMessage,
                conversationHistory: conversationHistory ?? [],
                currentTimeNatural: currentTimeNatural,
                userTimezone: userTimezone,
                tapLocation: tapLocation
            )
        } catch let error as PlaidError {
            await logPlaidError(error)
            return await recoverFromPlaidError(error, userMessage: userMessage, tapLocation: tapLocation)
        } catch {
            await logPlaidError(PlaidError.internal("Unexpected error: \(error)"))
            return "Sorry, something went wrong. Try again?"
        }
    }

    // MARK: Post-Processing (Full PLAID+ pipeline)

    private func postProcessPlaidResponse(
        raw: String,
        userMessage: String,
        conversationHistory: [Claude.ChatMessage],
        currentTimeNatural: String?,
        userTimezone: String?,
        tapLocation: Claude.TapLocationContext?
    ) async throws -> String {

        // ── STEP 1: EXTRACT JSON IF PRESENT ──────────────────────────────
        guard let jsonStr = extractJSON(from: raw) else {
            // No JSON → GATHERING mode
            let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.count > 280 || clean.contains("**") || clean.contains("```") {
                throw PlaidError.modelBrokeRules(violation: "GATHER mode: too long or contains markup")
            }
            return clean
        }

        // ── STEP 2: VALIDATE JSON STRUCTURE ──────────────────────────────
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaidError.invalidJSON(details: "Could not parse JSON")
        }

        let isReady = json["ready"] as? Bool ?? false

        // ── VALIDATE REQUIRED FIELDS ──────────────────────────────────────
        var missing: [String] = []
        if json["name"] as? String == nil { missing.append("name") }
        if json["location_name"] as? String == nil { missing.append("location_name") }
        if json["dttm_start_utc"] as? String == nil { missing.append("dttm_start_utc") }
        if json["dttm_end_utc"] as? String == nil { missing.append("dttm_end_utc") }

        // ── TIME VALIDATION ───────────────────────────────────────────────
        if let startStr = json["dttm_start_utc"] as? String,
           let endStr = json["dttm_end_utc"] as? String,
           let start = isoDate(from: startStr),
           let end = isoDate(from: endStr) {
            if start <= Date() {
                throw PlaidError.invalidTime(details: "Start time is in the past")
            }
            if end <= start {
                throw PlaidError.invalidTime(details: "End time must be after start")
            }
            if end.timeIntervalSince(start) > 86400 {
                throw PlaidError.invalidTime(details: "Duration exceeds 24 hours")
            }
        }

        // ── LOCATION VALIDATION ───────────────────────────────────────────
        if let loc = json["location_name"] as? String, !loc.isEmpty {
            let isValid = await isGeocodable(loc)
            if !isValid {
                throw PlaidError.noValidLocation
            }
        }

        // ── STEP 3: READY=TRUE → FINALIZE ─────────────────────────────────
        if isReady {
            if !missing.isEmpty {
                throw PlaidError.missingRequired(fields: missing)
            }
            // Return pure JSON for finalization
            return jsonStr
        }

        // ── STEP 4: READY=FALSE → PREVIEW ─────────────────────────────────
        if !missing.isEmpty {
            throw PlaidError.missingRequired(fields: missing)
        }

        // Valid preview
        if raw.lowercased().contains("here's your meetup") {
            return raw
        } else {
            return "Here's your meetup: \(jsonStr)"
        }
    }

    // MARK: JSON Extraction

    private func extractJSON(from text: String) -> String? {
        let regex = Regex {
            "{"
            Capture { OneOrMore(.any, .reluctant) }
            "}"
        }
        return text.firstMatch(of: regex).map { String($0.1) }
    }

    // MARK: Fallback UX

    private func generateFallbackQuestion(
        userMessage: String,
        tapLocation: Claude.TapLocationContext?
    ) -> String {
        if userMessage.lowercased().contains("where") || userMessage.lowercased().contains("location") {
            return "What's the exact address or venue name?"
        }
        if let name = tapLocation?.name, !name.isEmpty {
            return "Is this meetup at \(name)?"
        }
        return "Can you give me a specific location?"
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
                mutable["assumptions"] = (mutable["assumptions"] as? [String] ?? []) + ["forced finalize"]
                let updated = try JSONSerialization.data(
                    withJSONObject: mutable,
                    options: [.withoutEscapingSlashes, .sortedKeys]
                )
                return String(data: updated, encoding: .utf8)!
            }
        }
        // Safe default
        let start = nextHourISO()
        let end = nextHourISO(offset: 2)
        return """
        {"ready":true,"name":"Quick Meetup","location_name":"TBD","dttm_start_utc":"\(start)","dttm_end_utc":"\(end)","description":null,"meet_category_id":null,"invitees":[],"assumptions":["forced from no history"],"confidence":0.6}
        """
    }

    // MARK: Geocoding

    private func isGeocodable(_ location: String) async -> Bool {
        guard !location.isEmpty else { return false }
        let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URI(string: "https://nominatim.openstreetmap.org/search?format=json&q=\(query)&limit=1")
        
        do {
            let response = try await client.get(url) { req in
                req.headers.add(name: "User-Agent", value: "RangleyApp/1.0")
            }
            let results = try response.content.decode([[String: String]].self)
            return !results.isEmpty
        } catch {
            await logPlaidError(PlaidError.geocodeFailed)
            return false
        }
    }

    // MARK: Error Recovery UX

    private func recoverFromPlaidError(
        _ error: PlaidError,
        userMessage: String,
        tapLocation: Claude.TapLocationContext?
    ) async -> String {
        switch error {
        case .modelBrokeRules:
            return generateFallbackQuestion(userMessage: userMessage, tapLocation: tapLocation)
        case .missingRequired(let fields):
            if fields.contains("location_name") {
                return "I need a specific venue or address. Which one?"
            }
            return "Can you clarify the \(fields.first!)?"
        case .invalidTime:
            return "That time doesn't work. When should it be?"
        case .noValidLocation, .geocodeFailed:
            if let name = tapLocation?.name, !name.isEmpty {
                return "Is this at \(name)? Or give me a real address."
            }
            return "I need a real location — address or venue name?"
        case .finalizeWithoutPreview:
            return "I don't have a meetup to confirm yet. What do you want to plan?"
        default:
            return "Let me try again. What kind of meetup?"
        }
    }

    // MARK: ISO Helpers

    private func isoDate(from string: String?) -> Date? {
        guard let s = string else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: s)
    }

    private func nextHourISO(offset: Int = 0) -> String {
        let date = Calendar.current.date(byAdding: .hour, value: 1 + offset, to: Date())!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }

    // MARK: Logging

    private func logPlaidError(_ error: PlaidError) async {
        let payload = [
            "error": error.analyticsCode,
            "message": error.description,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        // Replace with your logger
        print("PLAID ERROR: \(payload)")
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

// MARK: - Request Extension

extension Request {
    var claudeService: ClaudeService {
        guard let cfg = application.claudeConfig else {
            fatalError("ClaudeConfig not configured. Call app.claudeConfig = try ClaudeConfig.fromEnvironment() in configure.swift")
        }
        return ClaudeService(config: cfg, client: client)
    }
}
