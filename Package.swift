// swift-tools-version: 5.9
import PackageDescription
import Foundation

let packageRootPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
    name: "Lexical",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Lexical", targets: ["Lexical"])
    ],
    targets: [
        .target(
            name: "LexicalCore",
            path: "LexicalCore",
            exclude: [
                "DesignSystem/LiquidGlassShader.metal"
            ]
        ),
        .executableTarget(
            name: "Lexical",
            dependencies: ["LexicalCore"],
            path: "Lexical",
            exclude: [
                "Info.plist",
                "PrivacyInfo.xcprivacy"
            ],
            resources: [
                .process("Resources/ArticleTemplateBank.json"),
                .process("Resources/Seeds/seed_data.json"),
                .process("Resources/Seeds/roots.json"),
                .process("Resources/StoreKit/Lexical.storekit"),
                .process("Resources/Icons/Tab"),
                .process("Resources/Icons/Settings")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(packageRootPath)/Lexical/Info.plist"
                ], .when(platforms: [.iOS]))
            ]
        ),
        .executableTarget(
            name: "LexicalWidget",
            dependencies: ["LexicalCore"],
            path: "LexicalWidget",
            exclude: [
                "Info.plist"
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-e", "_NSExtensionMain", // Extension entry point
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(packageRootPath)/LexicalWidget/Info.plist"
                ], .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "LexicalCoreTests",
            dependencies: ["LexicalCore"],
            path: "LexicalCoreTests"
        ),
        .testTarget(
            name: "LexicalTests",
            dependencies: ["Lexical", "LexicalCore"],
            path: "LexicalTests"
        ),
        .executableTarget(
            name: "Seeder",
            dependencies: ["LexicalCore"],
            path: "Seeder"
        )

    ]
)
