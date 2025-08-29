import Vapor
import App

@main
struct Run {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // New async factory (replaces deprecated Application(env))
        let app = try await Application.make(env)

        // Graceful async shutdown
        defer { Task { try? await app.asyncShutdown() } }

        // Listen on all interfaces; honor PORT env (ECS/Heroku-style)
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

        try configure(app)          // your existing (sync) configure() still works
        try await app.execute()     // async run loop
    }
}
