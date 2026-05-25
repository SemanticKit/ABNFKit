// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ABNFKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "ABNFKit",
            targets: ["ABNFKit"]
        )
    ],
    targets: [
        .target(
            name: "ABNFKit"
        ),
        .testTarget(
            name: "ABNFKitTests",
            dependencies: ["ABNFKit"],
            resources: [.copy("Data")]
        )
    ]
)
