// SMSService.swift
import Vapor
import Logging
import AWSPinpointSMSVoiceV2
import AWSClientRuntime

struct SMSService {
    private let client: PinpointSMSVoiceV2Client
    private let cfg: SMSConfig
    private let logger: Logger

    init(app: Application) {
        self.cfg = app.sms                            // <-- your SMSConfig from configure(_:)
        self.logger = app.logger
        let conf = try! PinpointSMSVoiceV2Client
            .PinpointSMSVoiceV2ClientConfiguration(region: cfg.region)
        self.client = PinpointSMSVoiceV2Client(config: conf)
    }

    /// Send a transactional SMS (OTP/alerts/etc.)
    @discardableResult
    func sendText(to e164: String, body: String, messageType overrideType: String? = nil) async throws -> String {
        let input = SendTextMessageInput(
            configurationSetName: cfg.configurationSetName,       // optional
            destinationPhoneNumber: e164,                         // +1...
            keyword: nil,                                         // only for short codes
            messageBody: body,
            messageType: .init(rawValue: (overrideType ?? cfg.defaultMessageType).uppercased()),
            originationIdentity: cfg.originationIdentity          // pool-* or ARN
        )

        logger.info("EUM: sending SMS to \(e164)")
        let out = try await client.sendTextMessage(input: input)
        let id = out.messageId ?? ""
        logger.info("EUM: sent SMS id=\(id)")
        return id
    }
}

// Request helper
extension Request {
    var smsService: SMSService { .init(app: application) }
}
