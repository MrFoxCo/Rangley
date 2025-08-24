import Vapor
import SQLKit

public func routes(_ app: Application) throws {
    app.get("health") { _ in "ok" }

    // Always returns 200 text/plain with details; never throws.
    app.get("dbdiag") { req async -> String in
        var lines: [String] = []
        lines.append("dbdiag:")

        let host = Environment.get("DB_HOST") ?? "(unset)"
        let port = Environment.get("DB_PORT") ?? "5432"
        let name = Environment.get("DB_NAME") ?? "(unset)"
        let user = Environment.get("DB_USER") ?? "(unset)"
        lines.append("env host=\(host) port=\(port) db=\(name) user=\(user)")

        guard let sql = req.db as? (any SQLDatabase) else {
            lines.append("adapter:error req.db is not SQLDatabase (driver/config missing)")
            return lines.joined(separator: "\n")
        }

        do {
            _ = try await sql.raw("select 1 as one").first()
            lines.append("query:ok select 1")
        } catch {
            lines.append("query:error \(String(describing: error))")
        }

        return lines.joined(separator: "\n")
    }
}
