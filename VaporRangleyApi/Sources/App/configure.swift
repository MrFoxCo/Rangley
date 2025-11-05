import Vapor
import Fluent
import FluentPostgresDriver
import NIOSSL
import JWT


@discardableResult
private func requireEnv(_ k: String) -> String {
    guard let v = Environment.get(k), !v.isEmpty else { fatalError("Missing ENV \(k)") }
    return v
}

public func configure(_ app: Application) async throws
{

    // MARK: - DATABASE
    
    let dbHost = requireEnv("DB_HOST")
    let dbPort = Int(Environment.get("DB_PORT") ?? "5432") ?? 5432
    let dbName = requireEnv("DB_NAME")
    let dbUser = requireEnv("DB_USER")
    let dbPass = requireEnv("password") // it's password not DB_PASSWORD now

    app.config = .init(dbHost: dbHost, dbPort: dbPort, dbName: dbName, dbUser: dbUser)

    // --- TLS for RDS (uses the bundle you COPY'd in your Dockerfile) ---
    var tls = TLSConfiguration.makeClientConfiguration()
    tls.certificateVerification = .fullVerification
    tls.trustRoots = .file("/etc/ssl/certs/rds-global-bundle.pem")
    let sslContext = try NIOSSLContext(configuration: tls)

    // --- New SQLPostgresConfiguration API ---
    let pg = SQLPostgresConfiguration(
        hostname: dbHost,
        port: dbPort,
        username: dbUser,
        password: dbPass,
        database: dbName,
        tls: .require(sslContext)
    )

    // New signature uses encoding/decoding contexts
    app.databases.use(
        .postgres(
            configuration: pg,
            maxConnectionsPerEventLoop: 10,
            connectionPoolTimeout: .seconds(10),
            encodingContext: .default,
            decodingContext: .default,
            sqlLogLevel: app.environment == .production ? .warning : .debug
        ),
        as: .psql
    )
    
    // MARK: - END DATABASE
    
    
    
    
    // MARK: - SMS CONFIGURATION
    
    let region = requireEnv("EUM_REGION")                 // "us-east-2"
    let origId = requireEnv("EUM_ORIGINATION_ID")         // "pool-xxxx..."
    let cfgSet = Environment.get("EUM_CONFIGURATION_SET")// optional

    app.sms = .init(
        region: region,
        originationIdentity: origId,       // pool ID (or ARN)
        configurationSetName: cfgSet,
        defaultMessageType: "TRANSACTIONAL"
    )
    
    // MARK: - END SMS
    
    
    // MARK: - CLAUDE CONFIGURATION

    app.claudeConfig = try ClaudeConfig.fromEnvironment()

    // MARK: - END CLAUDE
    
    
    
    // MARK: - COGNITO
    // Env
    let rawIssuer = requireEnv("COGNITO_ISSUER")
    let cognitoIssuer = rawIssuer.hasSuffix("/") ? String(rawIssuer.dropLast()) : rawIssuer
    let cognitoClientID = requireEnv("COGNITO_CLIENT_ID")
    
    let cognitoUserPoolId = requireEnv("COGNITO_USER_POOL_ID")

    app.storage[CognitoConfigKey.self] = CognitoConfig(
        issuer: cognitoIssuer,
        clientID: cognitoClientID,
        userPoolId: cognitoUserPoolId
    )

    // Make iss/aud available to middleware comparisons
    app.storage[IssuerKey.self]   = cognitoIssuer
    app.storage[AudienceKey.self] = cognitoClientID


    // === Load JWKS synchronously at boot ===
    let jwksURI = URI(string: "\(cognitoIssuer)/.well-known/jwks.json")
    let res = try await app.client.get(jwksURI, beforeSend: { req in
        req.headers.replaceOrAdd(name: .accept, value: "application/json")
    }).get()

    guard res.status == .ok, var body = res.body,
          let jwksJSON = body.readString(length: body.readableBytes) else {
        app.logger.critical("JWKS fetch failed (status: \(res.status)) from \(jwksURI)")
        throw Abort(.internalServerError, reason: "Failed to fetch JWKS")
    }

    // Bridge async add() onto NIO and block until it completes
    _ = try await app.eventLoopGroup.next().makeFutureWithTask {
        try await app.jwt.keys.add(jwksJSON: jwksJSON)
    }.get()

    app.logger.info("Loaded Cognito JWKS from \(jwksURI)")

    // MARK: - COGNITO ADMIN SERVICE
    let cognitoRegion = requireEnv("AWS_REGION") // e.g., "us-east-2"

    app.cognitoAdmin = try await CognitoAdminService(
        region: cognitoRegion,
        userPoolId: cognitoUserPoolId
    )

    app.logger.info("Configured Cognito Admin Service for region: \(cognitoRegion)")
    
    
    // MARK: - END COGNITO
    
    try routes(app)
}
// MARK: - Storage helpers (make Values Sendable)
struct CognitoConfig: Sendable {
    let issuer: String
    let clientID: String
    let userPoolId: String
}
struct CognitoConfigKey: StorageKey { typealias Value = CognitoConfig }
extension Application { var cognito: CognitoConfig { storage[CognitoConfigKey.self]! } }

struct AppAuthConfig: Sendable {
    let issuer: String
    let hmacSecret: [UInt8]
}
struct AppAuthConfigKey: StorageKey { typealias Value = AppAuthConfig }
extension Application { var appAuth: AppAuthConfig { storage[AppAuthConfigKey.self]! } }



private extension Array where Element == UInt8 {
    init(hexString: String) throws {
        let s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count % 2 == 0 else { throw Abort(.internalServerError, reason: "Odd-length hex secret") }
        var out = [UInt8](); out.reserveCapacity(s.count/2)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else {
                throw Abort(.internalServerError, reason: "Invalid hex in APP_JWT_HS256_SECRET")
            }
            out.append(b); i = j
        }
        self = out
    }
}
