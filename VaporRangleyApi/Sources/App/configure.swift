import Vapor
import Fluent
import FluentPostgresDriver
import NIOSSL

@discardableResult
private func requireEnv(_ k: String) -> String {
    guard let v = Environment.get(k), !v.isEmpty else { fatalError("Missing ENV \(k)") }
    return v
}

public func configure(_ app: Application) throws {
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

    try routes(app)
}
