import Vapor
import SQLKit

public func routes(_ app: Application) throws {
    app.get("health") { _ in "ok" }

    app.get("dbcheck") { req async throws -> String in
        let sql = req.db as! any SQLDatabase
        if let row = try await sql.raw("SELECT current_database() AS db, version() AS ver").first() {
            return "dbcheck ok: \(row)"
        }
        return "dbcheck ok"
    }
}
