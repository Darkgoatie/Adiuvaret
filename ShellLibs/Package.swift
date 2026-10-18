// swift-tools-version:5.3
import PackageDescription

// The command engine for the in-app shell: ios_system (BSD-3) and the command sets the assistant may use.
// ssh is left out. curl links libssh2 and openssl itself, so both ship even though ssh does not.
let package = Package(
    name: "ShellLibs",
    products: [.library(name: "ShellLibs", targets: ["ios_system", "awk", "curl_ios", "files", "shell", "tar", "text", "libssh2", "openssl"])],
    targets: [
        .binaryTarget(name: "ios_system", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/ios_system.xcframework.zip", checksum: "d2deb9f77dff839e069f21efdb11f16864a8173e33956cd1b4d174a76f1b0e99"),
        .binaryTarget(name: "awk", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/awk.xcframework.zip", checksum: "560f786c77d487a482de7fcd1caa4736a95979783483685d53a8503a7514e53f"),
        .binaryTarget(name: "curl_ios", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/curl_ios.xcframework.zip", checksum: "f9a74e005115aad3b51dd8daa2fb4727eb8425018805d7dd2973e598af65f968"),
        .binaryTarget(name: "files", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/files.xcframework.zip", checksum: "4e36aeb7242592a848a7ee3b74109dc45f63e16fa9fa4d07bc80026ec30897e3"),
        .binaryTarget(name: "shell", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/shell.xcframework.zip", checksum: "bdace8281617602f1f0da7c90d933388085e31de9f31964467671f212966f76a"),
        .binaryTarget(name: "tar", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/tar.xcframework.zip", checksum: "74146ae19720d3d885d181bce4be2b6b92f11d306a47aa07486bf0dd35fc8f68"),
        .binaryTarget(name: "text", url: "https://github.com/holzschu/ios_system/releases/download/v3.0.6/text.xcframework.zip", checksum: "9eef16c23ddaa03d5f28ce2183737b1dbdcfb06e6dc46035a404d9e0f3828604"),
        .binaryTarget(name: "libssh2", url: "https://github.com/holzschu/libssh2-apple/releases/download/v1.11.0/libssh2-dynamic.xcframework.zip", checksum: "cacfe1789b197b727119f7e32f561eaf9acc27bf38cd19975b74fce107f868a6"),
        .binaryTarget(name: "openssl", url: "https://github.com/holzschu/openssl-apple/releases/download/v1.1.1w/openssl-dynamic.xcframework.zip", checksum: "329e8317cf9bee8e138da5d032330a7a1bd2473cf44c9c083cb2f0636abb8b80"),
    ]
)
