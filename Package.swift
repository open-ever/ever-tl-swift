// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ever-tl-swift",
    platforms: [.macOS(.v13), .iOS(.v13)],
    products: [
        .library(name: "EverTL", targets: ["EverTL"]),
        .library(name: "EverTLCodegen", targets: ["EverTLCodegen"]),
        .executable(name: "ever-tl-codegen", targets: ["ever-tl-codegen"])
    ],
    targets: [
        .target(name: "EverTL"),
        .testTarget(name: "EverTLTests", dependencies: ["EverTL"]),
        .testTarget(
            name: "EverTLGeneratedTests",
            dependencies: ["EverTL", "EverTLCodegen"],
            resources: [.copy("Fixtures")]
        ),
        .target(name: "EverTLCodegen"),
        .executableTarget(name: "ever-tl-codegen", dependencies: ["EverTLCodegen"]),
        .testTarget(
            name: "EverTLCodegenTests",
            dependencies: ["EverTLCodegen"],
            resources: [.copy("Fixtures")]
        )
    ]
)
