//
//  PgDbManager.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 8/21/25.
//

import Foundation
import PostgresClientKit

public final class DbManager {
    public static let shared = DbManager()

    private let queue = DispatchQueue(label: "DbManager.postgres.serial")

    // Adjust these via your config/secrets
    private let host = "localhost"
    private let port = 15432
    private let database = "dbRangley_Prod"
    private let user = "rangley_app_prod"
    private let password = "<DEV_PASSWORD>" // pull from Keychain/Secure Enclave in real app
    private let useSSL = false              // tunnel is local; for direct RDS, use true + proper CA

    private init() {
        // No file bootstrap, no schema creation here for Postgres
        // (Do schema migrations server-side / via SQL scripts)
    }

    // MARK: - Core execution helpers

    @discardableResult
    public func execute(_ sql: String, _ bind: [PostgresValueConvertible] = []) -> Int {
        return queue.sync {
            do {
                var cfg = PostgresClientKit.ConnectionConfiguration()
                cfg.host = host
                cfg.port = port
                cfg.database = database
                cfg.user = user
                cfg.credential = .scramSHA256(password: password)
                cfg.ssl = useSSL

                let connection = try PostgresClientKit.Connection(configuration: cfg)
                defer { connection.close() }

                let statement = try connection.prepareStatement(text: sql)
                defer { statement.close() }

                let cursor = try statement.execute(parameterValues: bind.map { $0.postgresValue })
                defer { cursor.close() }

                // Return rows-affected when available
                return cursor.commandTag?.rows ?? 0
            } catch {
                print("PG exec error: \(error) for SQL: \(sql.prefix(200))")
                return 0
            }
        }
    }

    public func query(_ sql: String, _ bind: [PostgresValueConvertible] = []) -> [[String: Any]] {
        return queue.sync {
            do {
                var cfg = PostgresClientKit.ConnectionConfiguration()
                cfg.host = host
                cfg.port = port
                cfg.database = database
                cfg.user = user
                cfg.credential = .scramSHA256(password: password)
                cfg.ssl = useSSL

                let connection = try PostgresClientKit.Connection(configuration: cfg)
                defer { connection.close() }

                let statement = try connection.prepareStatement(text: sql)
                defer { statement.close() }

                var rowsOut: [[String: Any]] = []
                for row in try statement.execute(parameterValues: bind.map { $0.postgresValue }) {
                    var dict: [String: Any] = [:]
                    for (idx, col) in row.columns.enumerated() {
                        let name = row.columnDescriptors[idx].name
                        // Read as string by default; map as needed
                        dict[name] = try? col.string()
                    }
                    rowsOut.append(dict)
                }
                return rowsOut
            } catch {
                print("PG query error: \(error) for SQL: \(sql.prefix(200))")
                return []
            }
        }
    }
}
