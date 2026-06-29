// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "materialSpeed",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "materialSpeed", targets: ["materialSpeed"])
    ],
    targets: [
        .executableTarget(
            name: "materialSpeed",
            path: "Sources/materialSpeed"
        )
    ]
)
