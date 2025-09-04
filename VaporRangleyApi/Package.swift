// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VaporRangleyApi",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.10.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"), // pin to a recent 5.x
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
        .package(url: "https://github.com/soto-project/soto-core.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "JWT", package: "jwt"), // <- this brings the Vapor helpers
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "SotoCognitoIdentityProvider", package: "soto"),

            ],
            path: "Sources/App",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .executableTarget(
            name: "Run",
            dependencies: ["App"],
            path: "Sources/Run",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App",
                .product(name: "XCTVapor", package: "vapor")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        )
    ]
)
