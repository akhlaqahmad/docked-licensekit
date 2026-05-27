// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LicenseKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [.library(name: "LicenseKit", targets: ["LicenseKit"])],
    dependencies: [
        .package(url: "https://github.com/akhlaqahmad/docked-appcore.git", branch: "main")
    ],
    targets: [
        .target(name: "LicenseKit", dependencies: ["AppCore"])
    ]
)
