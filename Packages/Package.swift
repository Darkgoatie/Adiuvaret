// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdiuvaretPackages",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AdiuvaretCore", targets: ["AdiuvaretCore"]),
        .library(name: "PolicyEngine", targets: ["PolicyEngine"]),
    ],
    targets: [
        .target(name: "AdiuvaretCore", path: "AdiuvaretCore/Sources"),
        .target(name: "PolicyEngine", dependencies: ["AdiuvaretCore"], path: "PolicyEngine/Sources"),
        .testTarget(name: "PolicyEngineTests", dependencies: ["PolicyEngine"], path: "PolicyEngine/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
