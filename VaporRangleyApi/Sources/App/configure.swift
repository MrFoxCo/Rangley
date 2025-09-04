import Vapor
import Fluent
import FluentPostgresDriver
import NIOSSL
import JWT
import SotoCore
import SotoCognitoIdentityProvider

@discardableResult
private func requireEnv(_ k: String) -> String {
    guard let v = Environment.get(k), !v.isEmpty else { fatalError("Missing ENV \(k)") }
    return v
}

public func configure(_ app: Application) throws
{

    // MARK: - DATABASE
    
    let dbHost = requireEnv("DB_HOST")
    let dbPort = Int(Environment.get("DB_PORT") ?? "5432") ?? 5432
    let dbName = requireEnv("DB_NAME")
    let dbUser = requireEnv("DB_USER")
    let dbPass = requireEnv("DB_PASSWORD")

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
    
    
    
    
    // MARK: - COGNITO
    
    // --- Cognito config (single source of truth) ---
    let cognitoIssuer     = requireEnv("COGNITO_ISSUER")
    let cognitoClientID   = requireEnv("COGNITO_CLIENT_ID")
    let cognitoUserPoolId = requireEnv("COGNITO_USER_POOL_ID")
    app.storage[CognitoConfigKey.self] = CognitoConfig(
        issuer: cognitoIssuer,
        clientID: cognitoClientID,
        userPoolId: cognitoUserPoolId
    )

    let jwtIssuer = Environment.get("APP_JWT_ISSUER") ?? "https://api.mrfoxco.com"
    let secret    = requireEnv("APP_JWT_HS256_SECRET")

    app.storage[AppAuthConfigKey.self] = .init(
        issuer: jwtIssuer,
        hmacSecret: Array(secret.utf8) // harmless to keep if you use it elsewhere
    )

    // Register HS256 key for signing & verifying (kid optional, but you used it above)
    Task {
        let sym = SymmetricKey(data: Data(secret.utf8))
        await app.jwt.keys.add(hmac: .init(key: sym), digestAlgorithm: .sha256, kid: "app-hs256")
    }


    // --- Soto client v7 ---
    let region = Region(rawValue: requireEnv("AWS_REGION"))
    let aws    = AWSClient() // v7 default init
    app.storage[AWSClientKey.self] = aws
    app.storage[CognitoIDPKey.self] = CognitoIdentityProvider(client: aws, region: region)
    app.lifecycle.use(ShutdownAWS(client: aws))

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

struct AWSClientKey: StorageKey { typealias Value = AWSClient }
struct CognitoIDPKey: StorageKey { typealias Value = CognitoIdentityProvider }
extension Application {
    var aws: AWSClient { storage[AWSClientKey.self]! }
    var cognitoIDP: CognitoIdentityProvider { storage[CognitoIDPKey.self]! }
}
struct ShutdownAWS: LifecycleHandler {
    let client: AWSClient
    func shutdown(_ app: Application) { try? client.syncShutdown() }
}
// MARK: - Secret decoding helpers
private func decodeSecret(_ s: String) throws -> [UInt8] {
    if s.hasPrefix("b64:") {
        guard let data = Data(base64Encoded: String(s.dropFirst(4))) else {
            throw Abort(.internalServerError, reason: "Invalid base64 in APP_JWT_HS256_SECRET")
        }
        return [UInt8](data)
    }
    if s.hasPrefix("hex:") {
        return try [UInt8](hexString: String(s.dropFirst(4)))
    }
    // fallback: treat as raw utf8 (still fine if it's random)
    return Array(s.utf8)
}

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
