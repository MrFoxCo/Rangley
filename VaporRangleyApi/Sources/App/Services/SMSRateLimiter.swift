//
//  SMSRateLimiter.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/25/25.
//

import Vapor
import Foundation

// Enhanced rate limiting for SMS verification with IP protection
actor SMSRateLimiter {
    static let shared = SMSRateLimiter()
    
    private var phoneAttempts: [String: [Date]] = [:]
    private var ipAttempts: [String: [Date]] = [:]
    
    private init() {}
    
    func canSend(to phone: String, from ip: String) -> (allowed: Bool, reason: String?) {
        let now = Date()
        let oneHour = TimeInterval(3600)
        let oneDay = TimeInterval(86400)
        
        // Clean up old attempts
        phoneAttempts[phone] = phoneAttempts[phone]?.filter { now.timeIntervalSince($0) < oneDay } ?? []
        ipAttempts[ip] = ipAttempts[ip]?.filter { now.timeIntervalSince($0) < oneDay } ?? []
        
        // Phone-based limits
        let phoneRecentAttempts = phoneAttempts[phone] ?? []
        let phoneHourlyAttempts = phoneRecentAttempts.filter { now.timeIntervalSince($0) < oneHour }
        
        if phoneHourlyAttempts.count >= 3 {
            return (false, "phone_hourly_limit")
        }
        if phoneRecentAttempts.count >= 10 {
            return (false, "phone_daily_limit")
        }
        
        // IP-based limits (protect against botnets)
        let ipRecentAttempts = ipAttempts[ip] ?? []
        let ipHourlyAttempts = ipRecentAttempts.filter { now.timeIntervalSince($0) < oneHour }
        
        if ipHourlyAttempts.count >= 20 {  // 20 per hour per IP
            return (false, "ip_hourly_limit")
        }
        if ipRecentAttempts.count >= 100 {  // 100 per day per IP
            return (false, "ip_daily_limit")
        }
        
        return (true, nil)
    }
    
    func recordAttempt(for phone: String, from ip: String) {
        let now = Date()
        
        // Record phone attempt
        if phoneAttempts[phone] == nil {
            phoneAttempts[phone] = []
        }
        phoneAttempts[phone]?.append(now)
        
        // Record IP attempt
        if ipAttempts[ip] == nil {
            ipAttempts[ip] = []
        }
        ipAttempts[ip]?.append(now)
    }
    
    func getRemainingTime(for phone: String, from ip: String) -> (timeUntilReset: TimeInterval, reason: String)? {
        let now = Date()
        let oneHour = TimeInterval(3600)
        let oneDay = TimeInterval(86400)
        
        // Check phone limits first
        if let phoneAttempts = phoneAttempts[phone] {
            let hourlyAttempts = phoneAttempts.filter { now.timeIntervalSince($0) < oneHour }
            if hourlyAttempts.count >= 3 {
                let oldestInHour = hourlyAttempts.min() ?? now
                let timeUntilReset = oneHour - now.timeIntervalSince(oldestInHour)
                return (max(0, timeUntilReset), "phone_hourly")
            }
            if phoneAttempts.count >= 10 {
                let oldestInDay = phoneAttempts.min() ?? now
                let timeUntilReset = oneDay - now.timeIntervalSince(oldestInDay)
                return (max(0, timeUntilReset), "phone_daily")
            }
        }
        
        // Check IP limits
        if let ipAttempts = ipAttempts[ip] {
            let hourlyAttempts = ipAttempts.filter { now.timeIntervalSince($0) < oneHour }
            if hourlyAttempts.count >= 20 {
                let oldestInHour = hourlyAttempts.min() ?? now
                let timeUntilReset = oneHour - now.timeIntervalSince(oldestInHour)
                return (max(0, timeUntilReset), "ip_hourly")
            }
            if ipAttempts.count >= 100 {
                let oldestInDay = ipAttempts.min() ?? now
                let timeUntilReset = oneDay - now.timeIntervalSince(oldestInDay)
                return (max(0, timeUntilReset), "ip_daily")
            }
        }
        
        return nil
    }
}
