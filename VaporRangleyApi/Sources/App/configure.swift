import Vapor
import Fluent
import FluentPostgresDriver
import PostgresNIO
import NIOSSL

public func configure(_ app: Application) throws {
    let host =     Environment.get("DB_HOST"    ) ?? "127.0.0.1"
    let port = Int(Environment.get("DB_PORT"    ) ?? "5432") ?? 5432
    let user =     Environment.get("DB_USER"    ) ?? "postgres"
    let pass =     Environment.get("DB_PASSWORD") ?? ""
    let name =     Environment.get("DB_NAME"    ) ?? "postgres"

    // TLS: require SSL to RDS (or use `.prefer(sslContext)` if you don’t want to hard-require)
    let sslContext = try NIOSSLContext(configuration: .clientDefault)

    let pg = SQLPostgresConfiguration(
        hostname    : host,
        port        : port,
        username    : user,
        password    : pass,
        database    : name,
        tls         : .require(sslContext)
    )

    app.databases.use(
        .postgres(
            configuration               : pg,
            maxConnectionsPerEventLoop  : 5,
            connectionPoolTimeout       : .seconds(10),
            encodingContext             : .default,
            decodingContext             : .default,
            sqlLogLevel                 : .info
        ),
        as: .psql
    )

    try routes(app)
}
