import Vapor
import Fluent
import FluentPostgresDriver
import PostgresNIO
import NIOSSL

public func configure(_ app: Application) throws {
    app.logger.logLevel = app.environment == .production ? .info : .debug

    // Env
    guard
        let host = Environment.get("DB_HOST"),
        let user = Environment.get("DB_USER"),
        let pass = Environment.get("DB_PASSWORD"),
        let name = Environment.get("DB_NAME")
    else { fatalError("DB_* env vars missing") }
    let port = Int(Environment.get("DB_PORT") ?? "5432") ?? 5432

    // TLS (RDS CA baked at /etc/ssl/certs/rds-global-bundle.pem)
    var tls = TLSConfiguration.makeClientConfiguration()
    let ca = try NIOSSLCertificate.fromPEMFile("/etc/ssl/certs/rds-global-bundle.pem")
    tls.trustRoots = .certificates(ca)
    tls.certificateVerification = .fullVerification
    let ssl = try NIOSSLContext(configuration: tls)
    let tlsMode: PostgresConnection.Configuration.TLS = .require(ssl)

    // New config type
    let cfg = SQLPostgresConfiguration(
        hostname: host,
        port: port,
        username: user,
        password: pass,
        database: name,
        tls: tlsMode
    )

    // New registration signature (no deprecations)
    app.databases.use(
        .postgres(
            configuration: cfg,
            maxConnectionsPerEventLoop: 8,
            connectionPoolTimeout: .seconds(10),
            encodingContext: .default,
            decodingContext: .default
        ),
        as: .psql
    )
    app.databases.default(to: .psql) // ensure req.db hits this one

    try routes(app)
}
