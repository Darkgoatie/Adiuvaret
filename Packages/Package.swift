// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdiuvaretPackages",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AdiuvaretCore", targets: ["AdiuvaretCore"]),
        .library(name: "PolicyEngine", targets: ["PolicyEngine"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "ToolKit", targets: ["ToolKit"]),
        .library(name: "Diagnostics", targets: ["Diagnostics"]),
        .library(name: "ModelLibrary", targets: ["ModelLibrary"]),
    ],
    targets: [
        .target(name: "AdiuvaretCore", path: "AdiuvaretCore/Sources"),
        .target(name: "PolicyEngine", dependencies: ["AdiuvaretCore"], path: "PolicyEngine/Sources"),
        .target(name: "DesignSystem", path: "DesignSystem/Sources/DesignSystem", resources: [.copy("Resources/Fonts"), .process("Localizable.xcstrings")]),
        .target(name: "Persistence", path: "Persistence/Sources"),
        .target(name: "ToolKit", path: "ToolKit/Sources"),
        .target(name: "Diagnostics", path: "Diagnostics/Sources"),
        .target(name: "ModelLibrary", path: "ModelLibrary/Sources"),
        .testTarget(name: "ModelLibraryTests", dependencies: ["ModelLibrary"], path: "ModelLibrary/Tests"),
        .testTarget(name: "DiagnosticsTests", dependencies: ["Diagnostics"], path: "Diagnostics/Tests"),
        .testTarget(name: "ToolKitTests", dependencies: ["ToolKit"], path: "ToolKit/Tests"),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"], path: "Persistence/Tests"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], path: "DesignSystem/Tests/DesignSystemTests"),
        .testTarget(name: "PolicyEngineTests", dependencies: ["PolicyEngine"], path: "PolicyEngine/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
