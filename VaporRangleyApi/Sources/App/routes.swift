//
//  routes.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//
import Vapor
import Fluent
import SQLKit

public func routes(_ app: Application) throws {
    app.get("dbdiag") { req async -> String in
        let c = req.application.config
        var lines = [
            "dbdiag:",
            "host:\(c.dbHost) port:\(c.dbPort) name:\(c.dbName) user:\(c.dbUser)"
        ]

        // req.db is a Fluent Database; SQLKit adds .sql() if you import SQLKit
        guard let sql = req.db as? (any SQLDatabase) else {
            lines.append("adapter:error req.db is not SQLDatabase")
            return lines.joined(separator: "\n")
        }

        do {
            _ = try await sql.raw("select 1 as one").first()
            lines.append("query:ok select 1")
        } catch {
            lines.append("query:error \(error)")
        }

        return lines.joined(separator: "\n")
    }
}
