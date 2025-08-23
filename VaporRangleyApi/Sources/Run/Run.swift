import Vapor
import App

@main
struct Run {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)

        // schedule async shutdown safely
        defer { Task { try? await app.asyncShutdown() } }

        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port =
            Int(Environment.get("PORT") ?? "8080") ?? 8080

        try configure(app)
        try await app.execute()
    }
}
