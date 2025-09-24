//
//  SMSService.swift
//  VaporRangleyApi
//
//  Complete SMS service using AWS SNS REST API with Signature V4
//

import Foundation
import Vapor
import Crypto

struct SMSService {
    private let client: Client
    private let logger: Logger
    private let region: String
    private let accessKeyId: String
    private let secretAccessKey: String
    
    init(client: Client,
         logger: Logger = .init(label: "SMSService"),
         region: String? = nil,
         accessKeyId: String? = nil,
         secretAccessKey: String? = nil) {
        
        self.client = client
        self.logger = logger
        self.region = region ?? Environment.get("AWS_REGION") ?? "us-east-2"
        self.accessKeyId = accessKeyId ?? Environment.get("AWS_ACCESS_KEY_ID") ?? ""
        self.secretAccessKey = secretAccessKey ?? Environment.get("AWS_SECRET_ACCESS_KEY") ?? ""
    }
    
    /// Send SMS using AWS SNS REST API with proper signing
    func sendText(to phoneNumber: String, message: String, senderId: String? = nil) async throws {
        let host = "sns.\(region).amazonaws.com"
        let endpoint = "https://\(host)/"
        let service = "sns"
        let method = "POST"
        
        // Prepare the request parameters
        var parameters = [
            "Action": "Publish",
            "PhoneNumber": phoneNumber,
            "Message": message,
            "MessageAttributes.entry.1.Name": "AWS.SNS.SMS.SMSType",
            "MessageAttributes.entry.1.Value.DataType": "String",
            "MessageAttributes.entry.1.Value.StringValue": "Transactional",
            "Version": "2010-03-31"
        ]
        
        // Add sender ID if provided
        if let senderId = senderId {
            parameters["MessageAttributes.entry.2.Name"] = "AWS.SNS.SMS.SenderID"
            parameters["MessageAttributes.entry.2.Value.DataType"] = "String"
            parameters["MessageAttributes.entry.2.Value.StringValue"] = senderId
        }
        
        // Create form-encoded body
        let body = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(urlEncode($0.value))" }
            .joined(separator: "&")
        
        // Get current date/time for signing
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = dateFormatter.string(from: date)
        
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: date)
        
        // Create canonical request
        let hashedPayload = SHA256.hash(data: Data(body.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        
        let canonicalHeaders = """
        content-type:application/x-www-form-urlencoded
        host:\(host)
        x-amz-date:\(amzDate)
        """
        
        let signedHeaders = "content-type;host;x-amz-date"
        
        let canonicalRequest = """
        \(method)
        /
        
        \(canonicalHeaders)
        
        \(signedHeaders)
        \(hashedPayload)
        """
        
        // Create string to sign
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(amzDate)
        \(credentialScope)
        \(canonicalRequestHash)
        """
        
        // Calculate signature
        let signature = try calculateSignature(
            key: secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: service,
            stringToSign: stringToSign
        )
        
        // Create authorization header
        let authorizationHeader = """
        AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(credentialScope), \
        SignedHeaders=\(signedHeaders), Signature=\(signature)
        """
        
        // Create headers
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
        headers.add(name: "X-Amz-Date", value: amzDate)
        headers.add(name: .authorization, value: authorizationHeader)
        
        logger.info("Sending SMS to \(phoneNumber)")
        
        // Make the request
        let response = try await client.post(
            URI(string: endpoint),
            headers: headers,
            beforeSend: { req in
                req.body = ByteBuffer(string: body)
            }
        )
        
        if response.status == .ok {
            logger.info("SMS sent successfully")
            if let responseBody = response.body {
                let responseString = String(buffer: responseBody)
                logger.debug("Response: \(responseString)")
            }
        } else {
            logger.error("Failed to send SMS: \(response.status)")
            if let responseBody = response.body {
                let errorMessage = String(buffer: responseBody)
                logger.error("Error details: \(errorMessage)")
            }
            throw Abort(.internalServerError, reason: "Failed to send SMS")
        }
    }
    
    // MARK: - Helper Functions
    
    private func urlEncode(_ string: String) -> String {
        // AWS requires specific encoding
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "*", with: "%2A")
            .replacingOccurrences(of: "%7E", with: "~") ?? string
    }
    
    private func calculateSignature(
        key: String,
        dateStamp: String,
        region: String,
        service: String,
        stringToSign: String
    ) throws -> String {
        let kSecret = "AWS4\(key)"
        let kDate = HMAC<SHA256>.authenticationCode(for: Data(dateStamp.utf8), using: SymmetricKey(data: Data(kSecret.utf8)))
        let kRegion = HMAC<SHA256>.authenticationCode(for: Data(region.utf8), using: SymmetricKey(data: kDate))
        let kService = HMAC<SHA256>.authenticationCode(for: Data(service.utf8), using: SymmetricKey(data: kRegion))
        let kSigning = HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: SymmetricKey(data: kService))
        
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: SymmetricKey(data: kSigning))
        return signature.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Application Extension

extension Application {
    var smsService: SMSService {
        .init(client: self.client, logger: self.logger)
    }
}

// MARK: - Request Extension for Easy Use

extension Request {
    var smsService: SMSService {
        .init(client: self.client, logger: self.logger)
    }
}

// MARK: - Usage Example

/*
// In your routes file:
func routes(_ app: Application) throws {
    app.post("send-otp") { req async throws -> HTTPStatus in
        struct OTPRequest: Content {
            let phoneNumber: String
            let code: String
        }
        
        let otpReq = try req.content.decode(OTPRequest.self)
        let message = "Your verification code is: \(otpReq.code). Do not share this code."
        
        try await req.smsService.sendText(
            to: otpReq.phoneNumber,
            message: message
        )
        
        return .ok
    }
}

// Or in a controller:
final class AuthController {
    func sendOTP(req: Request) async throws -> HTTPStatus {
        let phoneNumber = try req.content.get(String.self, at: "phoneNumber")
        let otp = String(format: "%06d", Int.random(in: 0...999999))
        
        // Save OTP to database here...
        
        try await req.smsService.sendText(
            to: phoneNumber,
            message: "Your OTP is: \(otp)"
        )
        
        return .ok
    }
}
*/
