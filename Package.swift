// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lexical",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "Lexical", targets: ["Lexical"])
    ],
    targets: [
        .target(
            name: "LexicalCore",
            path: "LexicalCore"
        ),
        .executableTarget(
            name: "Lexical",
            dependencies: ["LexicalCore"],
            path: "Lexical",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Lexical/Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "LexicalWidget",
            dependencies: ["LexicalCore"],
            path: "LexicalWidget",
            linkerSettings: [
                .unsafeFlags([
                    "-e", "_NSExtensionMain", // Extension entry point
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "LexicalWidget/Info.plist"
                ])
            ]
        )
    ]
)
