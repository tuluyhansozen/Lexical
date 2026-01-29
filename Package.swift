// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lexical",
    platforms: [
        .iOS(.v17) // Targeting modern iOS
    ],
    products: [
        .executable(name: "Lexical", targets: ["Lexical"])
    ],
    targets: [
        .executableTarget(
            name: "Lexical",
            path: "Lexical",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Lexical/Info.plist"
                ])
            ]
        )
    ]
)
