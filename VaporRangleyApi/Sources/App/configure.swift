//
//  configure.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//

import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application) throws {
    app.config = .init(
        dbHost: Environment.get("DB_HOST") ?? "(unset)",
        dbPort: Int(Environment.get("DB_PORT") ?? "5432") ?? 5432,
        dbName: Environment.get("DB_NAME") ?? "(unset)",
        dbUser: Environment.get("DB_USER") ?? "(unset)"
    )

    app.databases.use(.postgres(
        configuration: .init(
            hostname: app.config.dbHost,
            port: app.config.dbPort,
            username: app.config.dbUser,
            password: Environment.get("DB_PASSWORD") ?? "",
            database: app.config.dbName,
            tls: .prefer(try! .init(configuration: .clientDefault)) // or .disable
        )
    ), as: .psql)

    try routes(app)
}
